package com.taxiuap.backend.identity.service;

import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.DatosConductorRequest;
import com.taxiuap.backend.identity.dto.HabilitarUsuarioRequest;
import com.taxiuap.backend.identity.dto.UsuarioAdminResponse;
import com.taxiuap.backend.identity.entity.Administrador;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.enums.SituacionCarnet;
import com.taxiuap.backend.identity.enums.TipoRegistroUsuario;
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
 * conductor de taxi o delivery (con su moto y documentos) y administrador, una o varias a la vez,
 * para personas ya registradas.
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
        Set<TipoRegistroUsuario> tipos = tiposPedidos(datos);
        boolean delivery = tipos.contains(TipoRegistroUsuario.DELIVERY);
        if (delivery && (tipos.contains(TipoRegistroUsuario.CONDUCTOR) || tipos.contains(TipoRegistroUsuario.AMBOS))) {
            throw new NegocioException("Una persona tiene una sola cuenta de conductor: elija conductor de taxi o delivery");
        }
        List<RolSistema> roles = new ArrayList<>();
        if (tipos.contains(TipoRegistroUsuario.PASAJERO) || tipos.contains(TipoRegistroUsuario.AMBOS)) {
            roles.add(RolSistema.PASAJERO);
        }
        if (delivery || tipos.contains(TipoRegistroUsuario.CONDUCTOR) || tipos.contains(TipoRegistroUsuario.AMBOS)) {
            roles.add(RolSistema.CONDUCTOR);
        }
        if (tipos.contains(TipoRegistroUsuario.ADMIN)) roles.add(RolSistema.ADMIN);
        for (RolSistema rol : roles) {
            if (cuentaUsuarioService.tieneCuenta(persona.getId(), rol)) {
                throw new ConflictoException("La persona ya tiene un usuario de tipo " + rol.getCodigo());
            }
        }

        // Todo se valida antes de crear registros o guardar archivos.
        boolean incluyeConductor = roles.contains(RolSistema.CONDUCTOR);
        DatosConductorRequest datosConductor = datos.conductor();
        Map<TipoDocumento, MultipartFile> documentos = Map.of();
        if (incluyeConductor) {
            if (datosConductor == null) {
                throw new NegocioException("Faltan los datos del conductor (licencia y motocicleta)");
            }
            if (delivery) datosConductor = datosConductor.conCategoria(registroMotoConductorService.idCategoriaDelivery());
            documentos = registroMotoConductorService.validar(datosConductor, archivos);
        } else if (!archivos.isEmpty()) {
            throw new NegocioException("Solo se adjuntan documentos al habilitar un conductor");
        }
        // Pasajero y conductor comparten credenciales (las de una cuenta anterior si la hay); la de
        // administrador usa las del formulario.
        Credenciales comunes = roles.stream().anyMatch(rol -> rol != RolSistema.ADMIN)
                ? resolverCredenciales(persona, datos, false) : null;
        Credenciales deAdmin = roles.contains(RolSistema.ADMIN) ? resolverCredenciales(persona, datos, true) : null;

        List<UsuarioAdminResponse> creados = new ArrayList<>();
        for (RolSistema rol : roles) {
            Credenciales credenciales = rol == RolSistema.ADMIN ? deAdmin : comunes;
            Usuario usuario = cuentaUsuarioService.crearUsuario(persona, rol, credenciales.nombreUsuario(),
                    credenciales.passwordHash());
            switch (rol) {
                case PASAJERO -> cuentaUsuarioService.crearPasajero(usuario);
                case CONDUCTOR -> {
                    Conductor conductor = cuentaUsuarioService.crearConductor(usuario,
                            datosConductor.numeroLicencia().trim(), datosConductor.categoriaLicencia());
                    if (delivery && datos.limiteAdelantoCompra() != null) {
                        conductor.setLimiteAdelantoCompra(datos.limiteAdelantoCompra());
                    }
                    registroMotoConductorService.registrar(conductor, datosConductor, documentos);
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
        Persona persona = usuario.getPersona();
        if (estado == EstadoRegistro.A && Boolean.TRUE.equals(persona.getSuspendidaSinSelfie())) {
            // El administrador la habilita sin la foto con el carnet: ya no se vuelve a suspender sola (la app
            // se la sigue pidiendo, sin plazo).
            persona.setSuspendidaSinSelfie(false);
            persona.setSelfieExigida(false);
            persona.setPlazoSelfieCarnet(null);
        }
        return aRespuesta(usuario);
    }

    public Usuario buscarNoEliminado(Long idUsuario) {
        return usuarioRepository.findById(idUsuario)
                .filter(u -> u.getEstadoUsuario() != EstadoRegistro.X)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", idUsuario));
    }

    /** Con un pedido o un viaje en curso no se corta la cuenta: primero debe terminar o cancelarse. */
    private void validarSinViajeEnCurso(Usuario usuario, String accion) {
        if (tieneViajeEnCurso(usuario)) {
            throw new NegocioException("No se puede " + accion + " la cuenta: tiene un viaje o una solicitud en curso. "
                    + "Espere a que termine o se cancele");
        }
    }

    /** La cuenta tiene una solicitud o un viaje sin terminar (como pasajero o como conductor). */
    public boolean tieneViajeEnCurso(Usuario usuario) {
        List<SituacionViaje> finales = List.of(SituacionViaje.COMPLETADO, SituacionViaje.CANCELADO);
        return pasajeroRepository.findByUsuarioId(usuario.getId())
                .map(p -> solicitudViajeRepository.existsByPasajeroIdAndSituacionSolicitudInAndEstadoSolViaje(
                                p.getId(), List.of(SituacionSolicitud.PENDIENTE, SituacionSolicitud.CON_OFERTAS),
                                EstadoRegistro.A)
                        || viajeRepository.findFirstByPasajeroIdAndSituacionViajeNotIn(p.getId(), finales).isPresent())
                .orElse(false)
                || conductorRepository.findByUsuarioId(usuario.getId())
                        .map(c -> viajeRepository.findFirstByConductorIdAndSituacionViajeNotIn(c.getId(), finales).isPresent())
                        .orElse(false);
    }

    private record Credenciales(String nombreUsuario, String passwordHash) {
    }

    /** tipos (varios) y tipo (uno, compatibilidad) juntos; al menos uno. */
    private static Set<TipoRegistroUsuario> tiposPedidos(HabilitarUsuarioRequest datos) {
        Set<TipoRegistroUsuario> tipos = EnumSet.noneOf(TipoRegistroUsuario.class);
        if (datos.tipos() != null) datos.tipos().stream().filter(Objects::nonNull).forEach(tipos::add);
        if (datos.tipo() != null) tipos.add(datos.tipo());
        if (tipos.isEmpty()) throw new NegocioException("Elija al menos un tipo de usuario");
        return tipos;
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
                usuario.getEstadoUsuario().name(),
                situacion(usuario),
                fotoConCarnet(usuario),
                persona.getCarnetSelfieUrl() == null ? persona.getPlazoSelfieCarnet() : null,
                CarnetService.carnetVencido(persona));
    }

    private static String fotoConCarnet(Usuario usuario) {
        Persona persona = usuario.getPersona();
        if (RolSistema.ADMIN.getCodigo().equals(usuario.getRol().getCodigo())) return null;
        if (persona.getCarnetSelfieUrl() != null) return "SUBIDA";
        if (Boolean.TRUE.equals(persona.getSuspendidaSinSelfie())) return "SUSPENDIDA";
        if (Boolean.FALSE.equals(persona.getSelfieExigida())) return "SIN_PLAZO";
        return persona.getPlazoSelfieCarnet() != null ? "PENDIENTE" : null;
    }

    /**
     * Situacion de la cuenta para el filtro del panel: SUSPENDIDO (cuenta en S o conductor suspendido),
     * OBSERVADO (carnet esperando revision), PENDIENTE / RECHAZADO (conductor sin aprobar) o HABILITADO.
     */
    public String situacion(Usuario usuario) {
        if (usuario.getEstadoUsuario() == EstadoRegistro.S) return "SUSPENDIDO";
        if (usuario.getPersona().getSituacionCarnet() == SituacionCarnet.OBSERVADO) return "OBSERVADO";
        if (RolSistema.CONDUCTOR.getCodigo().equals(usuario.getRol().getCodigo())) {
            SituacionAprobacion aprobacion = conductorRepository.findByUsuarioId(usuario.getId())
                    .map(Conductor::getSituacionAprobacion).orElse(SituacionAprobacion.PENDIENTE);
            return switch (aprobacion) {
                case APROBADO -> "HABILITADO";
                case PENDIENTE -> "PENDIENTE";
                case RECHAZADO -> "RECHAZADO";
                case SUSPENDIDO -> "SUSPENDIDO";
            };
        }
        return "HABILITADO";
    }
}
