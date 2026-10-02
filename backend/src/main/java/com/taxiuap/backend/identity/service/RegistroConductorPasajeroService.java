package com.taxiuap.backend.identity.service;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.ReglasRegistro;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.dto.RegistroConductorEstadoResponse;
import com.taxiuap.backend.identity.dto.RegistroConductorPasajeroRequest;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.pricing.service.QrPagoConductorService;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.ConflictoException;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.vehicle.enums.TipoDocumento;
import com.taxiuap.backend.vehicle.service.RegistroMotoConductorService;

import lombok.RequiredArgsConstructor;

/**
 * Registro como conductor de alguien que ya es pasajero (opcion de Mas). La cuenta de conductor
 * comparte usuario y contrasena con la de pasajero (regla 12) y queda PENDIENTE: el pasajero sigue
 * entrando como pasajero hasta que el administrador lo apruebe.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RegistroConductorPasajeroService {

    private final UsuarioRepository usuarioRepository;
    private final ConductorRepository conductorRepository;
    private final GestionPersonaService gestionPersonaService;
    private final CuentaUsuarioService cuentaUsuarioService;
    private final RegistroMotoConductorService registroMotoConductorService;
    private final QrPagoConductorService qrPagoConductorService;
    private final CarnetService carnetService;
    private final LicenciaService licenciaService;
    private final CredencialesCorreoService credencialesCorreoService;

    public RegistroConductorEstadoResponse estado(Long idUsuario) {
        Usuario pasajero = cuentaPasajero(idUsuario);
        Persona persona = pasajero.getPersona();
        return new RegistroConductorEstadoResponse(
                conductorDe(persona).map(Conductor::getSituacionAprobacion).orElse(null),
                persona.getCorreo(),
                persona.getNombres(),
                persona.getApellidos(),
                persona.getCi(),
                persona.getComplementoCi(),
                persona.getTelefono(),
                persona.getFechaNacimiento(),
                carnetService.tieneCarnet(persona));
    }

    @Transactional
    public RegistroConductorEstadoResponse registrar(Long idUsuario, RegistroConductorPasajeroRequest datos,
            Map<String, MultipartFile> archivos) {
        Usuario pasajero = cuentaPasajero(idUsuario);
        Persona persona = pasajero.getPersona();
        if (conductorDe(persona).isPresent()) {
            throw new ConflictoException("Ya enviaste tu registro de conductor");
        }
        // Se valida todo antes de crear nada para no dejar registros a medias. El carnet que ya
        // registro como pasajero se reutiliza (con su CI, complemento y fecha de nacimiento).
        Map<TipoDocumento, MultipartFile> documentos = registroMotoConductorService.validar(datos.conductor(), archivos, false);
        List<byte[]> qrs = qrPagoConductorService.validarDelRegistro(archivos);
        CarnetService.FotosCarnet carnet = carnetService.validarDelRegistro(persona, archivos);
        LicenciaService.FotosLicencia licencia = licenciaService.validarDelRegistro(archivos);
        boolean conservarCarnet = carnet == null;
        // Carnet observado (la persona dice que se leyo mal): no se compara con la lectura ni con el
        // numero de la licencia; lo revisa el administrador.
        boolean pidioRevision = !conservarCarnet && datos.esObservado();
        if (!pidioRevision) {
            carnetService.verificarLectura(carnet, datos.ci(), datos.complementoCi(), datos.fechaNacimiento(),
                    datos.nombres(), datos.apellidos());
        }
        licenciaService.validarDatosRegistro(datos.conductor(), licencia,
                pidioRevision ? null : conservarCarnet ? persona.getCi() : datos.ci(),
                pidioRevision ? null : conservarCarnet ? persona.getComplementoCi() : datos.complementoCi());

        gestionPersonaService.actualizar(persona.getId(), new PersonaRequest(
                conservarCarnet ? persona.getCi() : datos.ci(),
                conservarCarnet ? persona.getComplementoCi() : datos.complementoCi(),
                conservarCarnet ? persona.getNombres() : ReglasRegistro.nombreOActual(datos.nombres(), persona.getNombres()),
                conservarCarnet ? persona.getApellidos() : ReglasRegistro.nombreOActual(datos.apellidos(), persona.getApellidos()),
                conservarCarnet ? persona.getFechaNacimiento() : datos.fechaNacimiento(),
                persona.getCorreo(), datos.telefono()));
        boolean observado = false;
        if (carnet != null) {
            carnetService.guardar(persona, carnet);
            observado = carnetService.revisar(persona, pidioRevision, datos.aceptoTerminos());
        }
        Usuario usuario = cuentaUsuarioService.crearUsuario(persona, RolSistema.CONDUCTOR,
                pasajero.getNombreUsuario(), pasajero.getPasswordHash());
        Conductor conductor = cuentaUsuarioService.crearConductor(usuario, datos.conductor().numeroLicencia(),
                datos.conductor().categoriaLicencia());
        registroMotoConductorService.registrar(conductor, datos.conductor(), documentos);
        licenciaService.guardar(conductor, licencia, datos.conductor().vencimientoLicencia());
        qrPagoConductorService.guardarDelRegistro(conductor, qrs);
        // Observado: sin aprobar ni correo hasta que el administrador revise sus datos.
        if (!observado) {
            boolean aprobado = licenciaService.aprobarSiVerificada(conductor, licencia);
            credencialesCorreoService.conductorRegistrado(usuario, null, "la misma de tu cuenta de pasajero", aprobado);
        }
        return estado(idUsuario);
    }

    private Usuario cuentaPasajero(Long idUsuario) {
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de pasajero"));
        if (!RolSistema.PASAJERO.getCodigo().equals(usuario.getRol().getCodigo())) {
            throw new NegocioException("El usuario no tiene perfil de pasajero");
        }
        return usuario;
    }

    /** Cuenta de conductor activa de la persona, si ya se registro. */
    private Optional<Conductor> conductorDe(Persona persona) {
        return usuarioRepository.findByPersonaId(persona.getId()).stream()
                .filter(u -> u.getEstadoUsuario() == EstadoRegistro.A)
                .filter(u -> RolSistema.CONDUCTOR.getCodigo().equals(u.getRol().getCodigo()))
                .findFirst()
                .flatMap(u -> conductorRepository.findByUsuarioId(u.getId()));
    }
}
