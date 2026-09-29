package com.taxiuap.backend.identity.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.HabilitarUsuarioRequest;
import com.taxiuap.backend.identity.dto.UsuarioAdminResponse;
import com.taxiuap.backend.identity.entity.Administrador;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.AdministradorRepository;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.ConflictoException;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.trip.repository.ViajeRepository;
import com.taxiuap.backend.vehicle.enums.TipoDocumento;
import com.taxiuap.backend.vehicle.service.RegistroMotoConductorService;

import lombok.RequiredArgsConstructor;

/**
 * Cuentas de usuario desde el panel admin: solo el administrador habilita cuentas de pasajero,
 * conductor (con su moto y documentos) o administrador para personas ya registradas.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class GestionUsuarioService {

    private final UsuarioRepository usuarioRepository;
    private final PasajeroRepository pasajeroRepository;
    private final ConductorRepository conductorRepository;
    private final AdministradorRepository administradorRepository;
    private final GestionPersonaService gestionPersonaService;
    private final CuentaUsuarioService cuentaUsuarioService;
    private final RegistroMotoConductorService registroMotoConductorService;
    private final ViajeRepository viajeRepository;
    private final SolicitudViajeRepository solicitudViajeRepository;

    public List<UsuarioAdminResponse> listar() {
        return usuarioRepository.findByEstadoUsuarioInOrderByIdAsc(List.of(EstadoRegistro.A, EstadoRegistro.S)).stream()
                .map(this::aRespuesta)
                .toList();
    }

    @Transactional
    public List<UsuarioAdminResponse> habilitar(Long idPersona, HabilitarUsuarioRequest datos,
            Map<String, MultipartFile> archivos) {
        Persona persona = gestionPersonaService.buscarActiva(idPersona);
        List<RolSistema> roles = switch (datos.tipo()) {
            case PASAJERO -> List.of(RolSistema.PASAJERO);
            case CONDUCTOR -> List.of(RolSistema.CONDUCTOR);
            case AMBOS -> List.of(RolSistema.PASAJERO, RolSistema.CONDUCTOR);
            case ADMIN -> List.of(RolSistema.ADMIN);
        };
        for (RolSistema rol : roles) {
            if (cuentaUsuarioService.tieneCuenta(persona.getId(), rol)) {
                throw new ConflictoException("La persona ya tiene un usuario de tipo " + rol.getCodigo());
            }
        }

        // Todo se valida antes de crear registros o guardar archivos.
        boolean incluyeConductor = roles.contains(RolSistema.CONDUCTOR);
        Map<TipoDocumento, MultipartFile> documentos = Map.of();
        if (incluyeConductor) {
            if (datos.conductor() == null) {
                throw new NegocioException("Faltan los datos del conductor (licencia y motocicleta)");
            }
            documentos = registroMotoConductorService.validar(datos.conductor(), archivos);
        } else if (!archivos.isEmpty()) {
            throw new NegocioException("Solo se adjuntan documentos al habilitar un conductor");
        }
        Credenciales credenciales = resolverCredenciales(persona, datos, roles.contains(RolSistema.ADMIN));

        List<UsuarioAdminResponse> creados = new ArrayList<>();
        for (RolSistema rol : roles) {
            Usuario usuario = cuentaUsuarioService.crearUsuario(persona, rol, credenciales.nombreUsuario(),
                    credenciales.passwordHash());
            switch (rol) {
                case PASAJERO -> cuentaUsuarioService.crearPasajero(usuario);
                case CONDUCTOR -> {
                    Conductor conductor = cuentaUsuarioService.crearConductor(usuario,
                            datos.conductor().numeroLicencia().trim(), datos.conductor().categoriaLicencia());
                    registroMotoConductorService.registrar(conductor, datos.conductor(), documentos);
                }
                case ADMIN -> {
                    Administrador administrador = new Administrador();
                    administrador.setUsuario(usuario);
                    administrador.setCargo(datos.cargo() == null || datos.cargo().isBlank() ? null : datos.cargo().trim());
                    administradorRepository.save(administrador);
                }
            }
            creados.add(aRespuesta(usuario));
        }
        return creados;
    }

    /**
     * Borrado logico de una cuenta y de su perfil (pasajero, conductor o administrador). No se
     * puede eliminar la propia cuenta.
     */
    @Transactional
    public void eliminar(Long idUsuario, Long idUsuarioActual) {
        if (idUsuario.equals(idUsuarioActual)) {
            throw new NegocioException("No puede eliminar su propio usuario");
        }
        Usuario usuario = buscarNoEliminado(idUsuario);
        validarSinViajeEnCurso(usuario, "eliminar");

        usuario.setEstadoUsuario(EstadoRegistro.X);
        pasajeroRepository.findByUsuarioId(idUsuario).ifPresent(p -> p.setEstadoPasajero(EstadoRegistro.X));
        conductorRepository.findByUsuarioId(idUsuario).ifPresent(c -> c.setEstadoConductor(EstadoRegistro.X));
        administradorRepository.findByUsuarioId(idUsuario).ifPresent(a -> a.setEstadoAdmin(EstadoRegistro.X));
    }

    /**
     * Suspende (S) o vuelve a habilitar (A) una cuenta. La suspendida no puede ingresar y su sesion
     * abierta se corta en su siguiente peticion (JwtAuthFilter). No toca las otras cuentas de la
     * persona: suspender al pasajero no suspende su cuenta de conductor.
     */
    @Transactional
    public UsuarioAdminResponse cambiarEstado(Long idUsuario, EstadoRegistro estado, Long idUsuarioActual) {
        if (estado != EstadoRegistro.A && estado != EstadoRegistro.S) {
            throw new NegocioException("El estado debe ser A (activa) o S (suspendida)");
        }
        if (idUsuario.equals(idUsuarioActual)) {
            throw new NegocioException("No puede suspender su propio usuario");
        }
        Usuario usuario = buscarNoEliminado(idUsuario);
        if (estado == EstadoRegistro.S) {
            validarSinViajeEnCurso(usuario, "suspender");
        }
        usuario.setEstadoUsuario(estado);
        return aRespuesta(usuario);
    }

    private Usuario buscarNoEliminado(Long idUsuario) {
        return usuarioRepository.findById(idUsuario)
                .filter(u -> u.getEstadoUsuario() != EstadoRegistro.X)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", idUsuario));
    }

    /** Con un pedido o un viaje en curso no se corta la cuenta: primero debe terminar o cancelarse. */
    private void validarSinViajeEnCurso(Usuario usuario, String accion) {
        List<SituacionViaje> finales = List.of(SituacionViaje.COMPLETADO, SituacionViaje.CANCELADO);
        boolean ocupado = pasajeroRepository.findByUsuarioId(usuario.getId())
                .map(p -> solicitudViajeRepository.existsByPasajeroIdAndSituacionSolicitudIn(p.getId(),
                                List.of(SituacionSolicitud.PENDIENTE, SituacionSolicitud.CON_OFERTAS))
                        || viajeRepository.findFirstByPasajeroIdAndSituacionViajeNotIn(p.getId(), finales).isPresent())
                .orElse(false)
                || conductorRepository.findByUsuarioId(usuario.getId())
                        .map(c -> viajeRepository.findFirstByConductorIdAndSituacionViajeNotIn(c.getId(), finales).isPresent())
                        .orElse(false);
        if (ocupado) {
            throw new NegocioException("No se puede " + accion + " la cuenta: tiene un viaje o una solicitud en curso. "
                    + "Espere a que termine o se cancele");
        }
    }

    private record Credenciales(String nombreUsuario, String passwordHash) {
    }

    /**
     * Las cuentas de pasajero y conductor de una persona comparten credenciales: si ya tiene una,
     * la nueva reutiliza su nombre de usuario y contrasena. Las de administrador son propias.
     */
    private Credenciales resolverCredenciales(Persona persona, HabilitarUsuarioRequest datos, boolean esAdmin) {
        if (!esAdmin) {
            Optional<Usuario> existente = usuarioRepository
                    .findByPersonaIdAndEstadoUsuario(persona.getId(), EstadoRegistro.A).stream()
                    .filter(u -> !u.getRol().getCodigo().equals(RolSistema.ADMIN.getCodigo()))
                    .findFirst();
            if (existente.isPresent()) {
                return new Credenciales(existente.get().getNombreUsuario(), existente.get().getPasswordHash());
            }
        }

        if (datos.nombreUsuario() == null || datos.nombreUsuario().isBlank()
                || datos.password() == null || datos.password().isBlank()) {
            throw new NegocioException("Indique el nombre de usuario y la contrasena");
        }
        String nombreUsuario = CuentaUsuarioService.normalizarNombreUsuario(datos.nombreUsuario());
        cuentaUsuarioService.validarNombreUsuarioDisponible(nombreUsuario, persona.getId());
        return new Credenciales(nombreUsuario, cuentaUsuarioService.codificar(datos.password()));
    }

    private UsuarioAdminResponse aRespuesta(Usuario usuario) {
        Persona persona = usuario.getPersona();
        return new UsuarioAdminResponse(
                usuario.getId(),
                persona.getId(),
                persona.getNombres(),
                persona.getApellidos(),
                persona.getCi(),
                usuario.getNombreUsuario(),
                persona.getCorreo(),
                persona.getTelefono(),
                usuario.getRol().getCodigo(),
                usuario.getFechaRegistro(),
                usuario.getEstadoUsuario().name());
    }
}
