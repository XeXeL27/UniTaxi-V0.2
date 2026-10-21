package com.taxiuap.backend.communication.service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.communication.dto.AtenderAyudaIngresoRequest;
import com.taxiuap.backend.communication.dto.AyudaIngresoLoginRequest;
import com.taxiuap.backend.communication.dto.AyudaIngresoResponse;
import com.taxiuap.backend.communication.dto.RespuestaAyudaIngresoRequest;
import com.taxiuap.backend.communication.entity.SolicitudAyudaIngreso;
import com.taxiuap.backend.communication.enums.OrigenAyudaIngreso;
import com.taxiuap.backend.communication.enums.ProblemaIngreso;
import com.taxiuap.backend.communication.enums.SituacionAyudaIngreso;
import com.taxiuap.backend.communication.repository.SolicitudAyudaIngresoRepository;
import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.identity.service.AutenticacionService;
import com.taxiuap.backend.identity.service.CredencialesCorreoService;
import com.taxiuap.backend.identity.service.GestionUsuarioService;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Mensajes al administrador de quienes no pueden ingresar (Personas > Problemas de ingreso del panel):
 * desde el registro, cuando los codigos por correo no alcanzaron, y desde el login, marcando sus
 * problemas (cuenta suspendida, olvide mi contrasena, otro...). Cada mensaje deja a la persona 24 horas
 * sin poder enviar otro del mismo lado (los del registro tambien frenan los codigos de recuperacion).
 * El administrador habilita la cuenta, la mantiene suspendida o le escribe un correo.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AyudaIngresoService {

    public static final Duration ESPERA_TRAS_MENSAJE = Duration.ofHours(24);
    private static final Duration VENTANA_IP = Duration.ofHours(1);
    private static final DateTimeFormatter FORMATO_HASTA = DateTimeFormatter.ofPattern("dd/MM/yyyy 'a las' HH:mm");

    /** Mensajes que llegan desde el registro (Recuperar mis credenciales). */
    private static final Set<OrigenAyudaIngreso> DESDE_REGISTRO = EnumSet.of(OrigenAyudaIngreso.ESTUDIANTE_UAP,
            OrigenAyudaIngreso.REGISTRO_PASAJERO, OrigenAyudaIngreso.REGISTRO_CONDUCTOR);
    private static final Set<OrigenAyudaIngreso> DESDE_LOGIN = EnumSet.of(OrigenAyudaIngreso.LOGIN,
            OrigenAyudaIngreso.CUENTA_SUSPENDIDA);

    private final SolicitudAyudaIngresoRepository repositorio;
    private final UsuarioRepository usuarioRepository;
    private final CredencialesCorreoService credencialesCorreoService;
    private final AutenticacionService autenticacionService;
    private final GestionUsuarioService gestionUsuarioService;

    @Value("${taxiuap.ayuda-ingreso.mensajes-por-hora:10}")
    private int mensajesPorHora = 10;

    private final Map<String, Deque<Instant>> mensajesPorIp = new ConcurrentHashMap<>();
    private Clock reloj = Clock.systemDefaultZone();

    /** Solo para las pruebas: mover el tiempo. */
    void usarReloj(Clock reloj) {
        this.reloj = reloj;
    }

    @Transactional
    public SolicitudAyudaIngreso registrar(Persona persona, OrigenAyudaIngreso origen, String ru, String celular,
            String descripcion, String ip) {
        return registrar(persona, origen, ru, celular, null, descripcion, ip);
    }

    private SolicitudAyudaIngreso registrar(Persona persona, OrigenAyudaIngreso origen, String ru, String celular,
            String problemas, String descripcion, String ip) {
        SolicitudAyudaIngreso solicitud = new SolicitudAyudaIngreso();
        solicitud.setPersona(persona);
        solicitud.setOrigen(origen);
        solicitud.setRu(ru);
        solicitud.setCelular(celular);
        solicitud.setProblemas(problemas);
        solicitud.setDescripcion(descripcion == null ? null : descripcion.trim());
        solicitud.setIp(ip);
        solicitud.setFecha(LocalDateTime.now(reloj));
        return repositorio.save(solicitud);
    }

    /**
     * Mensaje desde el login: la persona se identifica con su usuario, correo, celular o carnet (y la
     * contrasena si la escribio) y marca sus problemas. Con OTRO escribe el motivo.
     */
    @Transactional
    public void desdeLogin(AyudaIngresoLoginRequest datos, String ip) {
        controlarLimite(ip);
        Set<ProblemaIngreso> problemas = EnumSet.copyOf(datos.problemas());
        String descripcion = datos.descripcion() == null ? "" : datos.descripcion().trim();
        if (problemas.contains(ProblemaIngreso.OTRO) && descripcion.length() < 10) {
            throw new NegocioException("Escribe el motivo de tu problema (al menos 10 letras)");
        }
        AutenticacionService.PersonaAyuda encontrada = autenticacionService
                .personaParaAyuda(datos.identificador(), datos.password())
                .orElseThrow(() -> new NegocioException("No encontramos una cuenta con ese usuario, correo, celular o "
                        + "carnet. Revisa lo que escribiste."));
        Persona persona = encontrada.persona();
        Optional<LocalDateTime> hasta = ultimoMensajeHasta(persona, DESDE_LOGIN);
        if (hasta.isPresent()) {
            throw new NegocioException("Ya enviaste un mensaje al administrador y está revisando tu caso. Podrás "
                    + "enviar otro el " + hasta.get().format(FORMATO_HASTA) + ".");
        }
        OrigenAyudaIngreso origen = encontrada.suspendidaVerificada()
                ? OrigenAyudaIngreso.CUENTA_SUSPENDIDA : OrigenAyudaIngreso.LOGIN;
        String codigos = problemas.stream().map(Enum::name).collect(Collectors.joining(","));
        registrar(persona, origen, null, datos.celular().trim(), codigos, descripcion.isEmpty() ? null : descripcion, ip);
        log.info("Persona {} envio un mensaje al administrador desde el login ({}): {}", persona.getId(), origen, codigos);
    }

    /** Hasta cuando la persona espera para pedir codigos u otro mensaje desde el registro. */
    public Optional<LocalDateTime> bloqueadoHasta(Persona persona) {
        return ultimoMensajeHasta(persona, DESDE_REGISTRO);
    }

    private Optional<LocalDateTime> ultimoMensajeHasta(Persona persona, Set<OrigenAyudaIngreso> origenes) {
        return repositorio.findFirstByPersonaIdAndOrigenInAndEstadoSolAyudaIngOrderByFechaDesc(persona.getId(),
                        origenes, EstadoRegistro.A)
                .map(s -> s.getFecha().plus(ESPERA_TRAS_MENSAJE))
                .filter(hasta -> hasta.isAfter(LocalDateTime.now(reloj)));
    }

    public List<AyudaIngresoResponse> listar() {
        return repositorio.findByEstadoSolAyudaIngOrderByFechaDesc(EstadoRegistro.A).stream()
                .map(this::respuesta)
                .toList();
    }

    /** Para el contador del menu y la campana del panel. */
    public long pendientes() {
        return repositorio.countBySituacionAndEstadoSolAyudaIng(SituacionAyudaIngreso.PENDIENTE, EstadoRegistro.A);
    }

    @Transactional
    public AyudaIngresoResponse atender(Long id, AtenderAyudaIngresoRequest datos, JwtUser admin) {
        SolicitudAyudaIngreso solicitud = pendiente(id);
        if (datos.situacion() == SituacionAyudaIngreso.PENDIENTE) {
            throw new NegocioException("Elige si el mensaje quedó atendido o descartado");
        }
        cerrar(solicitud, datos.situacion(), datos.observacion().trim(), admin);
        return respuesta(solicitud);
    }

    /** Habilita las cuentas suspendidas de la app de la persona, le avisa por correo y cierra el caso. */
    @Transactional
    public AyudaIngresoResponse habilitar(Long id, RespuestaAyudaIngresoRequest datos, JwtUser admin) {
        SolicitudAyudaIngreso solicitud = pendiente(id);
        List<Usuario> suspendidas = cuentasSuspendidas(solicitud.getPersona());
        if (suspendidas.isEmpty()) {
            throw new NegocioException("La cuenta de esta persona no está suspendida");
        }
        suspendidas.forEach(u -> gestionUsuarioService.cambiarEstado(u.getId(), EstadoRegistro.A, admin.idUsuario()));
        credencialesCorreoService.cuentaHabilitada(solicitud.getPersona(), suspendidas.get(0).getNombreUsuario());
        String nota = texto(datos);
        cerrar(solicitud, SituacionAyudaIngreso.ATENDIDA,
                "Cuenta habilitada." + (nota.isEmpty() ? "" : " " + nota), admin);
        log.info("Problemas de ingreso {}: cuenta de la persona {} habilitada", id, solicitud.getPersona().getId());
        return respuesta(solicitud);
    }

    /** La cuenta sigue suspendida: se le envia el motivo por correo y se cierra el caso. */
    @Transactional
    public AyudaIngresoResponse mantenerSuspendida(Long id, RespuestaAyudaIngresoRequest datos, JwtUser admin) {
        SolicitudAyudaIngreso solicitud = pendiente(id);
        String motivo = texto(datos);
        if (motivo.length() < 5) {
            throw new NegocioException("Escribe el motivo por el que la cuenta sigue suspendida");
        }
        if (cuentasSuspendidas(solicitud.getPersona()).isEmpty()) {
            throw new NegocioException("La cuenta de esta persona no está suspendida");
        }
        credencialesCorreoService.cuentaSigueSuspendida(solicitud.getPersona(), motivo);
        cerrar(solicitud, SituacionAyudaIngreso.ATENDIDA, "Sigue suspendida: " + motivo, admin);
        return respuesta(solicitud);
    }

    /**
     * Correo del administrador a la persona. Con cerrar el caso queda atendido; sin cerrar sigue pendiente
     * (por ejemplo, esperando que la persona responda) y el correo queda anotado en la observacion.
     */
    @Transactional
    public AyudaIngresoResponse enviarCorreo(Long id, RespuestaAyudaIngresoRequest datos, JwtUser admin) {
        SolicitudAyudaIngreso solicitud = pendiente(id);
        Persona persona = solicitud.getPersona();
        if (persona.getCorreo() == null || persona.getCorreo().isBlank()) {
            throw new NegocioException("La persona no tiene correo registrado: comunícate a su celular "
                    + solicitud.getCelular());
        }
        String mensaje = texto(datos);
        if (mensaje.length() < 5) {
            throw new NegocioException("Escribe el mensaje del correo");
        }
        credencialesCorreoService.respuestaAdministrador(persona, mensaje);
        String nota = "Correo enviado: " + mensaje;
        if (Boolean.FALSE.equals(datos.cerrar())) {
            String anterior = solicitud.getObservacionAdmin();
            String fecha = LocalDateTime.now(reloj).format(DateTimeFormatter.ofPattern("dd/MM HH:mm"));
            solicitud.setObservacionAdmin(recortar((anterior == null ? "" : anterior + "\n") + fecha + " " + nota));
            repositorio.save(solicitud);
        } else {
            cerrar(solicitud, SituacionAyudaIngreso.ATENDIDA, nota, admin);
        }
        return respuesta(solicitud);
    }

    private SolicitudAyudaIngreso pendiente(Long id) {
        SolicitudAyudaIngreso solicitud = repositorio.findById(id)
                .filter(s -> s.getEstadoSolAyudaIng() == EstadoRegistro.A)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Mensaje", id));
        if (solicitud.getSituacion() != SituacionAyudaIngreso.PENDIENTE) {
            throw new NegocioException("Este mensaje ya fue atendido");
        }
        return solicitud;
    }

    private void cerrar(SolicitudAyudaIngreso solicitud, SituacionAyudaIngreso situacion, String observacion,
            JwtUser admin) {
        Usuario usuario = usuarioRepository.findById(admin.idUsuario())
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", admin.idUsuario()));
        String anterior = solicitud.getObservacionAdmin();
        solicitud.setSituacion(situacion);
        solicitud.setObservacionAdmin(recortar(anterior == null || anterior.isBlank() ? observacion
                : anterior + "\n" + observacion));
        solicitud.setFechaAtencion(LocalDateTime.now(reloj));
        solicitud.setUsuarioAdminAtendio(usuario);
        repositorio.save(solicitud);
    }

    private AyudaIngresoResponse respuesta(SolicitudAyudaIngreso solicitud) {
        Persona persona = solicitud.getPersona();
        Usuario activa = credencialesCorreoService.cuentasDeApp(persona).stream().findFirst().orElse(null);
        String estado = activa != null ? AyudaIngresoResponse.HABILITADA
                : !cuentasSuspendidas(persona).isEmpty() ? AyudaIngresoResponse.SUSPENDIDA
                : AyudaIngresoResponse.SIN_CUENTA;
        String motivo = !AyudaIngresoResponse.SUSPENDIDA.equals(estado) ? null
                : Boolean.TRUE.equals(persona.getSuspendidaSinSelfie())
                        ? "No subió la foto con su carnet dentro del plazo"
                        : "Suspendida por un administrador";
        // Suspendida: igual se muestra su usuario (las credenciales solo se reenvian a una cuenta activa).
        Usuario cuenta = activa != null ? activa : cuentasSuspendidas(persona).stream().findFirst().orElse(null);
        return AyudaIngresoResponse.de(solicitud, cuenta, estado, motivo);
    }

    private List<Usuario> cuentasSuspendidas(Persona persona) {
        return usuarioRepository.findByPersonaId(persona.getId()).stream()
                .filter(u -> u.getEstadoUsuario() == EstadoRegistro.S)
                .filter(CredencialesCorreoService::esCuentaDeApp)
                .toList();
    }

    private static String texto(RespuestaAyudaIngresoRequest datos) {
        return datos == null || datos.texto() == null ? "" : datos.texto().trim();
    }

    private static String recortar(String texto) {
        return texto.length() <= 1000 ? texto : texto.substring(texto.length() - 1000);
    }

    private void controlarLimite(String ip) {
        Instant ahora = reloj.instant();
        Deque<Instant> envios = mensajesPorIp.computeIfAbsent(ip == null ? "?" : ip, k -> new ArrayDeque<>());
        synchronized (envios) {
            while (!envios.isEmpty() && envios.peekFirst().isBefore(ahora.minus(VENTANA_IP))) {
                envios.pollFirst();
            }
            if (envios.size() >= mensajesPorHora) {
                throw new NegocioException("Enviaste muchos mensajes seguidos. Espera unos minutos e intenta de nuevo.");
            }
            envios.addLast(ahora);
        }
        if (mensajesPorIp.size() > 10_000) {
            mensajesPorIp.entrySet().removeIf(e -> e.getValue().isEmpty());
        }
    }
}
