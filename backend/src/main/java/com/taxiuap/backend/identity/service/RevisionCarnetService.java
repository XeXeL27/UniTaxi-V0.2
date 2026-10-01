package com.taxiuap.backend.identity.service;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.communication.service.NotificacionPushService;
import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.CambiarSituacionConductorRequest;
import com.taxiuap.backend.identity.dto.CarnetObservadoResponse;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.dto.RevisionCarnetRequest;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.enums.SituacionCarnet;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/**
 * Carnets OBSERVADOS (Personas > Carnets observados del panel): la persona indico al registrarse que
 * el sistema leyo mal sus datos, o su nombre parecia falso u ofensivo (NombresPermitidos). Solo el
 * administrador corrige esos datos mirando las fotos del carnet:
 *
 * - Aprobar: guarda los datos corregidos, la persona queda VERIFICADA y recien ahi le llegan sus
 *   credenciales por correo y una notificacion al telefono. Si es conductor, su cuenta de conductor
 *   tambien puede quedar aprobada.
 * - Rechazar: le llega el motivo por correo y su registro se elimina (borrado logico); se liberan su
 *   correo, su telefono y su CI para que pueda volver a registrarse.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class RevisionCarnetService {

    /** Inicio de motivo_observacion de una persona rechazada (lo lee JwtAuthFilter). */
    private static final String PREFIJO_RECHAZO = "Rechazado: ";

    private final PersonaRepository personaRepository;
    private final UsuarioRepository usuarioRepository;
    private final ConductorRepository conductorRepository;
    private final GestionPersonaService gestionPersonaService;
    private final GestionUsuarioService gestionUsuarioService;
    private final GestionConductorService gestionConductorService;
    private final CredencialesCorreoService credencialesCorreoService;
    private final NotificacionPushService notificacionPushService;

    @Transactional(readOnly = true)
    public List<CarnetObservadoResponse> listar() {
        return personaRepository.findBySituacionCarnetAndEstadoPersonaOrderByFechaObservacionAsc(
                SituacionCarnet.OBSERVADO, EstadoRegistro.A).stream()
                .map(this::aRespuesta)
                .toList();
    }

    public CarnetObservadoResponse aprobar(Long idPersona, RevisionCarnetRequest datos) {
        Persona persona = observada(idPersona);
        gestionPersonaService.actualizar(persona.getId(), new PersonaRequest(
                datos.ci().trim(),
                vacioANull(datos.complementoCi()),
                datos.nombres().trim(),
                datos.apellidos().trim(),
                datos.fechaNacimiento(),
                persona.getCorreo(),
                persona.getTelefono()));
        persona.setSituacionCarnet(SituacionCarnet.VERIFICADO);
        persona.setMotivoObservacion(null);
        persona.setFechaObservacion(null);

        List<Usuario> cuentas = credencialesCorreoService.cuentasDeApp(persona);
        Optional<Usuario> conductor = cuenta(cuentas, RolSistema.CONDUCTOR);
        Optional<Usuario> pasajero = cuenta(cuentas, RolSistema.PASAJERO);
        boolean enviado = conductor.map(c -> entregarConductor(c, Boolean.TRUE.equals(datos.aprobarConductor())))
                .orElse(false);
        pasajero.ifPresent(p -> entregarPasajero(p, enviado));
        cuentas.forEach(u -> notificacionPushService.enviar(u.getId(), Map.of(
                "tipo", "CUENTA_APROBADA",
                "titulo", "Tus datos fueron aprobados",
                "cuerpo", "Ya puedes usar UNITAXI. Te enviamos tu usuario y contraseña a tu correo.")));
        return aRespuesta(persona);
    }

    /**
     * Conductor: si el admin lo aprueba le llega "Tu cuenta de conductor fue aprobada" con sus
     * credenciales (GestionConductorService); si no, sus credenciales y el aviso de que su cuenta de
     * conductor sigue en revision.
     */
    private boolean entregarConductor(Usuario usuario, boolean aprobar) {
        Conductor conductor = conductorRepository.findByUsuarioId(usuario.getId()).orElse(null);
        if (conductor == null) return false;
        if (aprobar && conductor.getSituacionAprobacion() != SituacionAprobacion.APROBADO) {
            gestionConductorService.cambiarSituacion(conductor.getId(),
                    new CambiarSituacionConductorRequest(SituacionAprobacion.APROBADO, null));
            return true;
        }
        String contrasena = null;
        if (Boolean.TRUE.equals(usuario.getContrasenaGenerada())) {
            contrasena = CredencialesCorreoService.contrasenaLegible();
            credencialesCorreoService.aplicarEnCuentasDeApp(usuario.getPersona(), contrasena, false);
        }
        credencialesCorreoService.conductorRegistrado(usuario, contrasena, "la que elegiste al registrarte",
                conductor.getSituacionAprobacion() == SituacionAprobacion.APROBADO);
        return true;
    }

    /** Pasajero: su contrasena se genero sin entregar; ahora le llega con la bienvenida. */
    private void entregarPasajero(Usuario usuario, boolean yaRecibioCorreo) {
        if (Boolean.TRUE.equals(usuario.getContrasenaGenerada())) {
            String contrasena = CredencialesCorreoService.contrasenaLegible();
            credencialesCorreoService.aplicarEnCuentasDeApp(usuario.getPersona(), contrasena, false);
            credencialesCorreoService.bienvenidaPasajero(usuario, contrasena, null);
        } else if (!yaRecibioCorreo) {
            credencialesCorreoService.bienvenidaPasajero(usuario, null, "la que ya usas para ingresar a UNITAXI");
        }
    }

    public void rechazar(Long idPersona, String motivo, Long idUsuarioActual) {
        Persona persona = observada(idPersona);
        String texto = motivo.trim();
        String correo = persona.getCorreo();
        credencialesCorreoService.registroRechazado(persona, correo, texto);
        List<Usuario> cuentas = credencialesCorreoService.cuentasDeApp(persona);
        cuentas.forEach(u -> notificacionPushService.enviar(u.getId(), Map.of(
                "tipo", "CUENTA_RECHAZADA",
                "titulo", "No pudimos aprobar tu registro",
                "cuerpo", texto)));

        boolean soloApp = usuarioRepository.findByPersonaId(persona.getId()).stream()
                .filter(u -> u.getEstadoUsuario() != EstadoRegistro.X)
                .allMatch(CredencialesCorreoService::esCuentaDeApp);
        if (soloApp) {
            gestionPersonaService.eliminar(persona.getId(), idUsuarioActual);
        } else {
            // Tambien es administrador: solo se eliminan sus cuentas de la app.
            cuentas.forEach(u -> gestionUsuarioService.eliminar(u.getId(), idUsuarioActual));
            persona.setCarnetAnversoUrl(null);
            persona.setCarnetReversoUrl(null);
        }
        // Se liberan el CI, el correo y el telefono para que pueda volver a registrarse.
        persona.setCi(null);
        persona.setComplementoCi(null);
        persona.setFechaNacimiento(null);
        if (soloApp) {
            persona.setCorreo(null);
            persona.setTelefono(null);
        }
        persona.setSituacionCarnet(null);
        String registro = PREFIJO_RECHAZO + texto + (correo != null ? " (" + correo + ")" : "");
        persona.setMotivoObservacion(registro.length() > 300 ? registro.substring(0, 300) : registro);
    }

    /**
     * Mensaje que ve en la app quien tenia la sesion abierta cuando el administrador rechazo sus
     * datos (vacio si la persona no fue rechazada).
     */
    public static Optional<String> mensajeRechazo(String motivoObservacion) {
        if (motivoObservacion == null || !motivoObservacion.startsWith(PREFIJO_RECHAZO)) return Optional.empty();
        String motivo = motivoObservacion.substring(PREFIJO_RECHAZO.length());
        int correo = motivo.lastIndexOf(" (");
        if (correo > 0) motivo = motivo.substring(0, correo);
        return Optional.of("No pudimos aprobar tu registro: " + motivo
                + ". Te enviamos el detalle a tu correo. Puedes registrarte de nuevo con fotos claras de tu carnet.");
    }

    private Persona observada(Long idPersona) {
        return personaRepository.findById(idPersona)
                .filter(p -> p.getEstadoPersona() == EstadoRegistro.A && p.carnetObservado())
                .orElseThrow(() -> new RecursoNoEncontradoException("No hay un carnet observado de esa persona"));
    }

    private static Optional<Usuario> cuenta(List<Usuario> cuentas, RolSistema rol) {
        return cuentas.stream().filter(u -> rol.getCodigo().equals(u.getRol().getCodigo())).findFirst();
    }

    private CarnetObservadoResponse aRespuesta(Persona persona) {
        List<Usuario> cuentas = credencialesCorreoService.cuentasDeApp(persona);
        Optional<Usuario> pasajero = cuenta(cuentas, RolSistema.PASAJERO);
        Optional<Usuario> cuentaConductor = cuenta(cuentas, RolSistema.CONDUCTOR);
        Optional<Conductor> conductor = cuentaConductor.flatMap(u -> conductorRepository.findByUsuarioId(u.getId()));
        String tipo = pasajero.isPresent() && cuentaConductor.isPresent() ? "Pasajero y conductor"
                : cuentaConductor.isPresent() ? "Conductor" : "Pasajero";
        Long idUsuario = cuentaConductor.or(() -> pasajero).map(Usuario::getId).orElse(null);
        return new CarnetObservadoResponse(
                persona.getId(),
                idUsuario,
                conductor.map(Conductor::getId).orElse(null),
                persona.getNombres(),
                persona.getApellidos(),
                persona.getCi(),
                persona.getComplementoCi(),
                persona.getFechaNacimiento(),
                persona.getCorreo(),
                persona.getTelefono(),
                tipo,
                conductor.map(Conductor::getNumeroLicencia).orElse(null),
                persona.getMotivoObservacion(),
                persona.getFechaObservacion());
    }

    private static String vacioANull(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim().toUpperCase();
    }
}
