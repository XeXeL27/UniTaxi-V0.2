package com.taxiuap.backend.identity.service;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayDeque;
import java.util.Base64;
import java.util.Comparator;
import java.util.Deque;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.communication.enums.OrigenAyudaIngreso;
import com.taxiuap.backend.communication.service.AyudaIngresoService;
import com.taxiuap.backend.identity.dto.CambiarContrasenaRecuperacionRequest;
import com.taxiuap.backend.identity.dto.CarnetRegistradoRequest;
import com.taxiuap.backend.identity.dto.CodigoRecuperacionResponse;
import com.taxiuap.backend.identity.dto.CuentaRegistradaResponse;
import com.taxiuap.backend.identity.dto.MensajeAyudaIngresoRequest;
import com.taxiuap.backend.identity.dto.RecuperacionTerminadaResponse;
import com.taxiuap.backend.identity.dto.VerificarCodigoRecuperacionRequest;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * "Recuperar mis credenciales" de quien intenta registrarse y ya lo estaba (mismo carnet o mismo RU).
 *
 * Al detectarlo se entrega un identificador temporal ([CuentaRegistradaResponse#recuperacion]); con el se
 * piden codigos de 6 digitos que llegan al correo REGISTRADO (nunca se escribe otro). Cada codigo vale
 * 90 segundos y se puede pedir otro recien a los 90 segundos, hasta 3 envios; despues del tercero se
 * espera 15 minutos para otra tanda y se habilita el mensaje al administrador (problema y celular). El
 * mensaje deja a la persona 24 horas sin pedir codigos ni otro mensaje. Con el codigo verificado pone
 * una contrasena nueva en sus cuentas de pasajero y conductor (regla 12) y vuelve al login; no entra sola.
 *
 * Los codigos y los identificadores viven en memoria (al reiniciar solo hay que volver a empezar); la
 * espera de 24 horas sale de los mensajes guardados.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional
public class RecuperarCuentaService {

    public static final int ENVIOS_MAXIMOS = 3;
    public static final Duration VIGENCIA_CODIGO = Duration.ofSeconds(90);
    public static final Duration ESPERA_REENVIO = Duration.ofSeconds(90);
    public static final Duration ESPERA_TRAS_LIMITE = Duration.ofMinutes(15);
    static final Duration VIDA_RECUPERACION = Duration.ofMinutes(30);
    static final Duration TIEMPO_PARA_CAMBIAR = Duration.ofMinutes(10);
    static final int INTENTOS_MAXIMOS = 5;
    private static final Duration VENTANA_IP = Duration.ofHours(1);
    private static final DateTimeFormatter FORMATO_HASTA = DateTimeFormatter.ofPattern("dd/MM 'a las' HH:mm");
    private static final SecureRandom AZAR = new SecureRandom();

    /** Lo que entrega el registro: de quien es y desde donde se pidio. */
    private record Recuperacion(Long idPersona, OrigenAyudaIngreso origen, String ru, Instant vence) {
    }

    /** Codigos de una persona (comun a todos sus identificadores, asi no se esquiva el limite). */
    private static final class Estado {
        String codigo;
        Instant venceCodigo;
        Instant ultimoEnvio;
        int envios;
        Instant reenvioDesde;
        boolean llegoAlLimite;
        int intentos;
        Instant verificadoHasta;
    }

    private final Map<String, Recuperacion> recuperaciones = new ConcurrentHashMap<>();
    private final Map<Long, Estado> estados = new ConcurrentHashMap<>();
    private final Map<String, Deque<Instant>> consultasPorIp = new ConcurrentHashMap<>();

    private final PersonaRepository personaRepository;
    private final UsuarioRepository usuarioRepository;
    private final CredencialesCorreoService credencialesCorreoService;
    private final AyudaIngresoService ayudaIngresoService;

    @Value("${taxiuap.recuperar.consultas-por-hora:30}")
    private int consultasPorHora = 30;

    private Clock reloj = Clock.systemDefaultZone();

    /** Solo para las pruebas: mover el tiempo. */
    void usarReloj(Clock reloj) {
        this.reloj = reloj;
    }

    /** El registro pregunta por un carnet (leido de la foto o escrito). Limite de consultas por IP. */
    public CuentaRegistradaResponse porCarnet(CarnetRegistradoRequest datos, String ip) {
        controlarLimite(ip);
        return personaPorCarnet(datos.ci(), datos.complementoCi())
                .map(p -> cuentaRegistrada(p, datos.origen(), null))
                .orElseGet(CuentaRegistradaResponse::noRegistrado);
    }

    /** Persona ya registrada: identificador para recuperar su cuenta (lo usa tambien el registro por RU). */
    public CuentaRegistradaResponse cuentaRegistrada(Persona persona, OrigenAyudaIngreso origen, String ru) {
        Instant ahora = reloj.instant();
        recuperaciones.values().removeIf(r -> r.vence().isBefore(ahora));
        byte[] bytes = new byte[24];
        AZAR.nextBytes(bytes);
        String id = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        recuperaciones.put(id, new Recuperacion(persona.getId(), origen, ru, ahora.plus(VIDA_RECUPERACION)));
        return new CuentaRegistradaResponse(true, id, ocultar(persona.getCorreo()), puedeRecibirCodigo(persona),
                sinCodigo(persona), ayudaIngresoService.bloqueadoHasta(persona).orElse(null));
    }

    public CodigoRecuperacionResponse enviarCodigo(String recuperacion) {
        Persona persona = persona(recuperacion);
        controlarEspera24(persona);
        String sinCodigo = sinCodigo(persona);
        if (sinCodigo != null) throw new NegocioException(sinCodigo + " Envía un mensaje al administrador.");
        Estado estado = estados.computeIfAbsent(persona.getId(), k -> new Estado());
        String valor;
        CodigoRecuperacionResponse respuesta;
        synchronized (estado) {
            Instant ahora = reloj.instant();
            if (estado.envios >= ENVIOS_MAXIMOS) {
                if (estado.reenvioDesde != null && estado.reenvioDesde.isAfter(ahora)) {
                    long minutos = (Duration.between(ahora, estado.reenvioDesde).toSeconds() + 59) / 60;
                    throw new NegocioException("Ya usaste los " + ENVIOS_MAXIMOS + " códigos. Podrás pedir otro en "
                            + minutos + " min o enviar un mensaje al administrador.");
                }
                estado.envios = 0;
            } else if (estado.ultimoEnvio != null && estado.ultimoEnvio.plus(ESPERA_REENVIO).isAfter(ahora)) {
                long faltan = Duration.between(ahora, estado.ultimoEnvio.plus(ESPERA_REENVIO)).toSeconds() + 1;
                throw new NegocioException("Ya te enviamos un código. Podrás pedir otro en " + faltan + " s");
            }
            valor = String.format("%06d", AZAR.nextInt(1_000_000));
            estado.codigo = valor;
            estado.venceCodigo = ahora.plus(VIGENCIA_CODIGO);
            estado.ultimoEnvio = ahora;
            estado.intentos = 0;
            estado.verificadoHasta = null;
            estado.envios++;
            long espera = ESPERA_REENVIO.toSeconds();
            if (estado.envios >= ENVIOS_MAXIMOS) {
                estado.llegoAlLimite = true;
                estado.reenvioDesde = ahora.plus(ESPERA_TRAS_LIMITE);
                espera = ESPERA_TRAS_LIMITE.toSeconds();
            }
            respuesta = new CodigoRecuperacionResponse(estado.envios, ENVIOS_MAXIMOS, VIGENCIA_CODIGO.toSeconds(),
                    espera, estado.llegoAlLimite, ocultar(persona.getCorreo()));
        }
        credencialesCorreoService.codigoRecuperarCuenta(persona, valor, VIGENCIA_CODIGO.toSeconds());
        return respuesta;
    }

    /** Con el codigo correcto hay unos minutos para escribir la contrasena nueva. */
    public void verificarCodigo(VerificarCodigoRecuperacionRequest datos) {
        Persona persona = persona(datos.recuperacion());
        Estado estado = estados.get(persona.getId());
        if (estado == null) throw new NegocioException("Primero pide el código");
        synchronized (estado) {
            Instant ahora = reloj.instant();
            if (estado.codigo == null || estado.venceCodigo.isBefore(ahora)) {
                estado.codigo = null;
                throw new NegocioException("El código venció. Pide uno nuevo");
            }
            if (!estado.codigo.equals(datos.codigo().trim())) {
                estado.intentos++;
                if (estado.intentos >= INTENTOS_MAXIMOS) {
                    estado.codigo = null;
                    throw new NegocioException("Demasiados intentos. Pide un código nuevo");
                }
                throw new NegocioException("El código no es correcto");
            }
            estado.codigo = null;
            estado.verificadoHasta = ahora.plus(TIEMPO_PARA_CAMBIAR);
        }
    }

    public RecuperacionTerminadaResponse cambiarContrasena(CambiarContrasenaRecuperacionRequest datos) {
        Persona persona = persona(datos.recuperacion());
        Estado estado = estados.get(persona.getId());
        if (estado == null || estado.verificadoHasta == null || estado.verificadoHasta.isBefore(reloj.instant())) {
            throw new NegocioException("Primero escribe el código que llegó a tu correo");
        }
        if (!datos.nueva().equals(datos.confirmacion())) {
            throw new NegocioException("La confirmación no coincide con la nueva contraseña");
        }
        List<Usuario> cuentas = credencialesCorreoService.cuentasDeApp(persona);
        if (cuentas.isEmpty()) throw new NegocioException("Tu cuenta ya no está activa. Comunícate con la administración.");
        credencialesCorreoService.aplicarEnCuentasDeApp(persona, datos.nueva(), false);
        terminar(persona.getId());
        String nombreUsuario = cuentas.get(0).getNombreUsuario();
        credencialesCorreoService.contrasenaRecuperada(persona, nombreUsuario);
        log.info("Persona {} recupero su cuenta con el codigo por correo", persona.getId());
        return new RecuperacionTerminadaResponse(nombreUsuario);
    }

    /**
     * Mensaje al administrador: solo despues de usar los 3 codigos (o si no tiene correo). La persona
     * espera 24 horas antes de volver a intentarlo.
     */
    public void enviarMensaje(MensajeAyudaIngresoRequest datos, String ip) {
        Recuperacion recuperacion = recuperacion(datos.recuperacion());
        Persona persona = persona(datos.recuperacion());
        controlarEspera24(persona);
        Estado estado = estados.get(persona.getId());
        if (puedeRecibirCodigo(persona) && (estado == null || !estado.llegoAlLimite)) {
            throw new NegocioException("Primero intenta con los " + ENVIOS_MAXIMOS + " códigos que podemos enviarte al correo");
        }
        ayudaIngresoService.registrar(persona, recuperacion.origen(), recuperacion.ru(), datos.celular(),
                datos.descripcion(), ip);
        terminar(persona.getId());
        log.info("Persona {} envio un mensaje al administrador porque no pudo ingresar", persona.getId());
    }

    private void terminar(Long idPersona) {
        estados.remove(idPersona);
        recuperaciones.values().removeIf(r -> r.idPersona().equals(idPersona));
    }

    private void controlarEspera24(Persona persona) {
        Optional<LocalDateTime> hasta = ayudaIngresoService.bloqueadoHasta(persona);
        if (hasta.isPresent()) {
            throw new NegocioException("Ya enviaste un mensaje al administrador. Podrás volver a intentarlo el "
                    + hasta.get().format(FORMATO_HASTA) + ".");
        }
    }

    private Recuperacion recuperacion(String id) {
        Recuperacion recuperacion = id == null ? null : recuperaciones.get(id);
        if (recuperacion == null || recuperacion.vence().isBefore(reloj.instant())) {
            throw new NegocioException("Pasó mucho tiempo. Vuelve a empezar la recuperación de tu cuenta.");
        }
        return recuperacion;
    }

    private Persona persona(String id) {
        Long idPersona = recuperacion(id).idPersona();
        return personaRepository.findById(idPersona)
                .filter(p -> p.getEstadoPersona() == EstadoRegistro.A)
                .orElseThrow(() -> new NegocioException("Tu cuenta ya no está activa. Comunícate con la administración."));
    }

    /**
     * Por que no se le puede enviar un codigo (null si se puede): sin correo, o sin cuentas activas de la
     * app (suspendida: cambiar la contrasena no la habilita, solo el administrador).
     */
    private String sinCodigo(Persona persona) {
        if (persona.getCorreo() == null || persona.getCorreo().isBlank()) {
            return "Tu cuenta no tiene un correo donde enviarte el código.";
        }
        if (credencialesCorreoService.cuentasDeApp(persona).isEmpty()) {
            boolean suspendida = usuarioRepository.findByPersonaId(persona.getId()).stream()
                    .anyMatch(u -> u.getEstadoUsuario() == EstadoRegistro.S && CredencialesCorreoService.esCuentaDeApp(u));
            return suspendida ? "Tu cuenta está suspendida: solo un administrador puede habilitarla."
                    : "Tu cuenta ya no está activa en la app.";
        }
        return null;
    }

    private boolean puedeRecibirCodigo(Persona persona) {
        return persona.getCorreo() != null && !persona.getCorreo().isBlank()
                && !credencialesCorreoService.cuentasDeApp(persona).isEmpty();
    }

    /**
     * La persona activa con ese carnet. Sin complemento escrito se prefiere la que tampoco lo tiene (el
     * complemento solo distingue carnets con el mismo numero).
     */
    private Optional<Persona> personaPorCarnet(String ci, String complemento) {
        String comp = complemento == null || complemento.isBlank() ? null : complemento.trim().toUpperCase(Locale.ROOT);
        return personaRepository.findByCiAndEstadoPersona(ci.trim(), EstadoRegistro.A).stream()
                .filter(p -> comp == null || comp.equalsIgnoreCase(p.getComplementoCi()))
                .min(Comparator.comparing(p -> p.getComplementoCi() == null || p.getComplementoCi().isBlank() ? 0 : 1));
    }

    private void controlarLimite(String ip) {
        Instant ahora = reloj.instant();
        Deque<Instant> pedidos = consultasPorIp.computeIfAbsent(ip == null ? "?" : ip, k -> new ArrayDeque<>());
        synchronized (pedidos) {
            while (!pedidos.isEmpty() && pedidos.peekFirst().isBefore(ahora.minus(VENTANA_IP))) {
                pedidos.pollFirst();
            }
            if (pedidos.size() >= consultasPorHora) {
                throw new NegocioException("Hiciste muchas consultas seguidas. Espera unos minutos e intenta de nuevo.");
            }
            pedidos.addLast(ahora);
        }
        if (consultasPorIp.size() > 10_000) {
            consultasPorIp.entrySet().removeIf(e -> e.getValue().isEmpty());
        }
    }

    static String ocultar(String correo) {
        if (correo == null || !correo.contains("@")) return null;
        String usuario = correo.substring(0, correo.indexOf('@'));
        return usuario.substring(0, Math.min(2, usuario.length())) + "***" + correo.substring(correo.indexOf('@'));
    }
}
