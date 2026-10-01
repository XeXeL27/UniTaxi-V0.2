package com.taxiuap.backend.identity.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Locale;
import java.util.Map;

import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.dto.DatosConductorRequest;
import com.taxiuap.backend.identity.dto.LicenciaRequest;
import com.taxiuap.backend.identity.dto.ReglasRegistro;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.enums.TipoPermisoEdicion;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/**
 * Licencia de conducir del conductor: fotos del anverso y del reverso (en la carpeta
 * conductor/licencia de la persona) y lo que la app leyo de ellas (numero, categoria y vencimiento).
 * Reemplaza al PDF de la licencia en el registro desde la app. Por ahora solo se aceptan licencias
 * de moto (categoria M).
 */
@Service
@RequiredArgsConstructor
@Transactional
public class LicenciaService {

    public static final String PARTE_ANVERSO = "LICENCIA_ANVERSO";
    public static final String PARTE_REVERSO = "LICENCIA_REVERSO";

    private final ConductorRepository conductorRepository;
    private final AlmacenamientoArchivos almacenamientoArchivos;
    private final CuentaUsuarioService cuentaUsuarioService;
    private final PermisoEdicionService permisoEdicionService;
    private final LecturaDocumentoService lecturaDocumentoService;

    /** Partes del multipart del registro de conductor que son fotos de la licencia (no PDF). */
    public static boolean esParteLicencia(String parte) {
        return PARTE_ANVERSO.equals(parte) || PARTE_REVERSO.equals(parte);
    }

    /** Fotos de la licencia ya procesadas (JPEG) y la huella de las fotos tal como llegaron. */
    public record FotosLicencia(byte[] anverso, byte[] reverso, String huellaAnverso, String huellaReverso) {
    }

    /** Fotos de la licencia del registro desde la app: obligatorias. */
    public FotosLicencia validarDelRegistro(Map<String, MultipartFile> archivos) {
        return validar(archivos.get(PARTE_ANVERSO), archivos.get(PARTE_REVERSO));
    }

    public FotosLicencia validar(MultipartFile anverso, MultipartFile reverso) {
        return new FotosLicencia(CarnetService.procesarFoto(anverso, "anverso", "licencia"),
                CarnetService.procesarFoto(reverso, "reverso", "licencia"),
                LecturaDocumentoService.huella(anverso), LecturaDocumentoService.huella(reverso));
    }

    /**
     * Datos de la licencia del registro desde la app: categoria M (moto), vigente y con el mismo
     * numero que el carnet (en Bolivia el numero de licencia es el del CI, con su complemento si lo
     * tiene: 6565204-1B).
     */
    @Transactional(readOnly = true)
    public void validarDatosRegistro(DatosConductorRequest datos, FotosLicencia fotos, String ci, String complemento) {
        lecturaDocumentoService.verificarLicencia(fotos.huellaAnverso(), fotos.huellaReverso(), datos.numeroLicencia(),
                datos.categoriaLicencia(), datos.vencimientoLicencia());
        validarDatos(datos.numeroLicencia(), datos.categoriaLicencia(), datos.vencimientoLicencia(), ci, complemento);
    }

    private static void validarDatos(String numero, String categoria, LocalDate vencimiento, String ci,
            String complemento) {
        if (!ReglasRegistro.CATEGORIA_MOTO.equals(normalizarCategoria(categoria))) {
            throw new NegocioException("Por ahora solo se aceptan licencias de motocicleta (categoria M)");
        }
        if (vencimiento == null) {
            throw new NegocioException("Falta la fecha de vencimiento de tu licencia");
        }
        if (vencimiento.isBefore(LocalDate.now())) {
            throw new NegocioException("Tu licencia de conducir esta vencida");
        }
        // "6565204-1B": numero del CI y, despues del guion, el complemento.
        String leido = numero == null ? "" : numero.trim().toUpperCase(Locale.ROOT);
        int guion = leido.indexOf('-');
        String soloNumero = guion < 0 ? leido : leido.substring(0, guion).trim();
        String complementoLicencia = guion < 0 ? "" : leido.substring(guion + 1).trim();
        if (ci != null && !ci.isBlank() && !soloNumero.equals(ci.trim())) {
            throw new NegocioException("El numero de tu licencia (" + leido
                    + ") no coincide con el de tu carnet (" + ci.trim() + ")");
        }
        String complementoCarnet = complemento == null ? "" : complemento.trim().toUpperCase(Locale.ROOT);
        if (!complementoLicencia.isEmpty() && !complementoCarnet.isEmpty() && !complementoLicencia.equals(complementoCarnet)) {
            throw new NegocioException("El complemento de tu licencia (" + complementoLicencia
                    + ") no coincide con el de tu carnet (" + complementoCarnet + ")");
        }
    }

    /**
     * Registro desde la app: si el servidor leyo con Gemini las fotos de la licencia y coincide con el
     * carnet (categoria M, vigente, numero = CI y el mismo nombre) el conductor queda APROBADO y puede
     * recibir solicitudes enseguida. Si no (lectura con ML Kit o en la web), sigue PENDIENTE hasta que
     * lo apruebe el administrador.
     */
    public boolean aprobarSiVerificada(Conductor conductor, FotosLicencia fotos) {
        if (conductor.getLicenciaAnversoUrl() == null || !lecturaDocumentoService.licenciaCoincide(
                fotos.huellaAnverso(), fotos.huellaReverso(), conductor.getUsuario().getPersona())) {
            return false;
        }
        conductor.setSituacionAprobacion(SituacionAprobacion.APROBADO);
        conductor.setFechaAprobacion(LocalDateTime.now());
        return true;
    }

    /** Guarda las fotos en personas/<id>_<ci>/conductor/licencia y el vencimiento en el conductor. */
    public void guardar(Conductor conductor, FotosLicencia fotos, LocalDate vencimiento) {
        Persona persona = conductor.getUsuario().getPersona();
        String carpeta = almacenamientoArchivos.carpetaLicencia(persona);
        conductor.setLicenciaAnversoUrl(almacenamientoArchivos.reemplazarConSello(conductor.getLicenciaAnversoUrl(),
                fotos.anverso(), carpeta, "licencia_anverso", "jpg"));
        conductor.setLicenciaReversoUrl(almacenamientoArchivos.reemplazarConSello(conductor.getLicenciaReversoUrl(),
                fotos.reverso(), carpeta, "licencia_reverso", "jpg"));
        conductor.setLicenciaVencimiento(vencimiento);
    }

    /**
     * El conductor vuelve a tomar las fotos de su licencia con un permiso del administrador
     * (LICENCIA) y confirmando con su contrasena.
     */
    public void reemplazarPorConductor(Long idUsuario, LicenciaRequest datos, MultipartFile anverso,
            MultipartFile reverso) {
        FotosLicencia fotos = validar(anverso, reverso);
        Conductor conductor = conductorRepository.findByUsuarioId(idUsuario)
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de conductor"));
        Usuario usuario = conductor.getUsuario();
        cuentaUsuarioService.confirmarContrasena(usuario, datos.password());
        lecturaDocumentoService.verificarLicencia(fotos.huellaAnverso(), fotos.huellaReverso(), datos.numeroLicencia(),
                datos.categoriaLicencia(), datos.vencimientoLicencia());
        validarDatos(datos.numeroLicencia(), datos.categoriaLicencia(), datos.vencimientoLicencia(),
                usuario.getPersona().getCi(), usuario.getPersona().getComplementoCi());
        permisoEdicionService.consumir(conductor.getId(), TipoPermisoEdicion.LICENCIA, null);
        conductor.setNumeroLicencia(datos.numeroLicencia().trim());
        conductor.setCategoriaLicencia(normalizarCategoria(datos.categoriaLicencia()));
        guardar(conductor, fotos, datos.vencimientoLicencia());
    }

    /**
     * El administrador corrige los datos de la licencia y, si las manda, cambia una o las dos fotos.
     * Puede poner cualquier categoria (P, M, A, B o C).
     */
    public void actualizarPorAdmin(Long idConductor, LicenciaRequest datos, MultipartFile anverso,
            MultipartFile reverso) {
        Conductor conductor = conductorRepository.findById(idConductor)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Conductor", idConductor));
        conductor.setNumeroLicencia(datos.numeroLicencia().trim());
        conductor.setCategoriaLicencia(normalizarCategoria(datos.categoriaLicencia()));
        conductor.setLicenciaVencimiento(datos.vencimientoLicencia());
        String carpeta = almacenamientoArchivos.carpetaLicencia(conductor.getUsuario().getPersona());
        if (anverso != null && !anverso.isEmpty()) {
            conductor.setLicenciaAnversoUrl(almacenamientoArchivos.reemplazarConSello(conductor.getLicenciaAnversoUrl(),
                    CarnetService.procesarFoto(anverso, "anverso", "licencia"), carpeta, "licencia_anverso", "jpg"));
        }
        if (reverso != null && !reverso.isEmpty()) {
            conductor.setLicenciaReversoUrl(almacenamientoArchivos.reemplazarConSello(conductor.getLicenciaReversoUrl(),
                    CarnetService.procesarFoto(reverso, "reverso", "licencia"), carpeta, "licencia_reverso", "jpg"));
        }
    }

    /** Foto de la licencia de un conductor ("anverso" o "reverso"). 404 si no la tiene. */
    @Transactional(readOnly = true)
    public Resource leer(Long idConductor, String lado) {
        Conductor conductor = conductorRepository.findById(idConductor)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Conductor", idConductor));
        return leer(conductor, lado);
    }

    @Transactional(readOnly = true)
    public Resource leerPorUsuario(Long idUsuario, String lado) {
        Conductor conductor = conductorRepository.findByUsuarioId(idUsuario)
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de conductor"));
        return leer(conductor, lado);
    }

    private Resource leer(Conductor conductor, String lado) {
        String ruta = switch (lado) {
            case "anverso" -> conductor.getLicenciaAnversoUrl();
            case "reverso" -> conductor.getLicenciaReversoUrl();
            default -> throw new NegocioException("Lado de la licencia no valido: " + lado);
        };
        if (ruta == null || !almacenamientoArchivos.existe(ruta)) {
            throw new RecursoNoEncontradoException("El conductor no registro la foto del " + lado + " de su licencia");
        }
        return almacenamientoArchivos.leer(ruta);
    }

    private static String normalizarCategoria(String categoria) {
        return categoria == null || categoria.isBlank() ? null : categoria.trim().toUpperCase(Locale.ROOT);
    }
}
