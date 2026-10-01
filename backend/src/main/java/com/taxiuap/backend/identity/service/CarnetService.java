package com.taxiuap.backend.identity.service;

import java.io.IOException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Map;

import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.ReglasRegistro;
import com.taxiuap.backend.identity.dto.CarnetRequest;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.dto.UsuarioResponse;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.SituacionCarnet;
import com.taxiuap.backend.identity.enums.TipoPermisoEdicion;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.archivo.ProcesadorImagen;
import com.taxiuap.backend.shared.exception.CredencialesInvalidasException;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/**
 * Carnet de identidad de quien entra con Google: fotos del anverso y del reverso (en la carpeta
 * general/carnet de la persona) y los datos que la app leyo de ellas (CI, complemento y fecha de
 * nacimiento). La app solo acepta fotos en las que reconoce un carnet boliviano.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class CarnetService {

    public static final String PARTE_ANVERSO = "CARNET_ANVERSO";
    public static final String PARTE_REVERSO = "CARNET_REVERSO";

    /** Motivo de un carnet OBSERVADO a pedido de la persona. */
    public static final String MOTIVO_PEDIDO = "La persona indicó que el sistema leyó mal sus datos";

    private final UsuarioRepository usuarioRepository;
    private final GestionPersonaService gestionPersonaService;
    private final AlmacenamientoArchivos almacenamientoArchivos;
    private final CredencialesCorreoService credencialesCorreoService;
    private final CuentaUsuarioService cuentaUsuarioService;
    private final PermisoEdicionService permisoEdicionService;
    private final ConductorRepository conductorRepository;
    private final LecturaDocumentoService lecturaDocumentoService;

    /** Partes del multipart del registro de conductor que son fotos del carnet (no PDF). */
    public static boolean esParteCarnet(String parte) {
        return PARTE_ANVERSO.equals(parte) || PARTE_REVERSO.equals(parte);
    }

    /**
     * Fotos del carnet ya procesadas (JPEG), listas para guardar, y la huella de las fotos tal como
     * llegaron (para buscar lo que Gemini leyo de ellas).
     */
    public record FotosCarnet(byte[] anverso, byte[] reverso, String huellaAnverso, String huellaReverso) {
    }

    /**
     * Los datos del carnet deben ser los que el servidor leyo de esas fotos (si las leyo con Gemini):
     * no se pueden cambiar a mano.
     */
    public void verificarLectura(FotosCarnet fotos, String ci, String complemento, LocalDate fechaNacimiento,
            String nombres, String apellidos) {
        if (fotos != null) {
            lecturaDocumentoService.verificarCarnet(fotos.huellaAnverso(), fotos.huellaReverso(), ci, complemento,
                    fechaNacimiento, nombres, apellidos);
        }
    }

    private void verificarLectura(FotosCarnet fotos, CarnetRequest datos) {
        verificarLectura(fotos, datos.ci(), datos.complementoCi(), datos.fechaNacimiento(), datos.nombres(),
                datos.apellidos());
    }

    /**
     * Con el carnet ya guardado: queda OBSERVADO si la persona pidio la revision ([pedido]) o si su
     * nombre no parece real (NombresPermitidos); si no, VERIFICADO. Mientras este observado no usa la
     * app ni recibe sus credenciales: las recibe cuando un administrador lo aprueba
     * (RevisionCarnetService). Devuelve true si quedo observado.
     */
    public boolean revisar(Persona persona, boolean pedido) {
        String motivo = pedido ? MOTIVO_PEDIDO : NombresPermitidos.problema(persona.getNombres(), persona.getApellidos());
        if (motivo == null) {
            persona.setSituacionCarnet(SituacionCarnet.VERIFICADO);
            persona.setMotivoObservacion(null);
            persona.setFechaObservacion(null);
            return false;
        }
        persona.setSituacionCarnet(SituacionCarnet.OBSERVADO);
        persona.setMotivoObservacion(motivo.length() > 300 ? motivo.substring(0, 300) : motivo);
        persona.setFechaObservacion(LocalDateTime.now());
        return true;
    }

    /**
     * Pantalla "Verifica tu carnet" de la app: guarda los datos y las fotos de la persona. Si queda
     * OBSERVADO, las credenciales esperan a que el administrador apruebe sus datos.
     */
    public UsuarioResponse registrar(Long idUsuario, CarnetRequest datos, MultipartFile anverso, MultipartFile reverso) {
        FotosCarnet fotos = validar(anverso, reverso);
        // Si la persona dice que sus datos se leyeron mal no se comparan con la lectura: los revisa el admin.
        if (!datos.esObservado()) verificarLectura(fotos, datos);
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new CredencialesInvalidasException("Credenciales invalidas"));
        Persona persona = usuario.getPersona();
        actualizarDatos(persona, datos);
        guardar(persona, fotos);
        if (!revisar(persona, datos.esObservado())) entregarCredenciales(usuario);
        return UsuarioResponse.de(usuario);
    }

    /**
     * Pasajero que entro con Google: sus credenciales llegan recien ahora, con el carnet guardado. El
     * correo sale despues de confirmar la transaccion (CorreoService), asi que si algo fallo no se envia.
     */
    private void entregarCredenciales(Usuario usuario) {
        Persona persona = usuario.getPersona();
        boolean pendiente = credencialesCorreoService.cuentasDeApp(persona).stream()
                .anyMatch(u -> Boolean.TRUE.equals(u.getContrasenaGenerada()));
        if (!pendiente || !RolSistema.PASAJERO.getCodigo().equals(usuario.getRol().getCodigo())) {
            return;
        }
        String contrasena = CredencialesCorreoService.contrasenaLegible();
        credencialesCorreoService.aplicarEnCuentasDeApp(persona, contrasena, false);
        credencialesCorreoService.bienvenidaPasajero(usuario, contrasena, null);
    }

    /** Fotos del carnet que llegan en un multipart (registro de conductor): obligatorias. */
    public FotosCarnet validarDelRegistro(Map<String, MultipartFile> archivos) {
        return validar(archivos.get(PARTE_ANVERSO), archivos.get(PARTE_REVERSO));
    }

    /**
     * Fotos del carnet del registro de conductor: si la persona ya registro su carnet (por ejemplo
     * como pasajero) se reutiliza y no se piden de nuevo; si no, son obligatorias. null = reutilizar.
     */
    public FotosCarnet validarDelRegistro(Persona persona, Map<String, MultipartFile> archivos) {
        if (persona != null && tieneCarnet(persona)) {
            return null;
        }
        return validarDelRegistro(archivos);
    }

    /** La persona ya tiene las dos fotos de su carnet y su CI. */
    public boolean tieneCarnet(Persona persona) {
        return persona.getCi() != null && !persona.getCi().isBlank()
                && almacenamientoArchivos.existe(persona.getCarnetAnversoUrl())
                && almacenamientoArchivos.existe(persona.getCarnetReversoUrl());
    }

    /**
     * El conductor vuelve a tomar las fotos de su carnet con un permiso del administrador (CARNET) y
     * confirmando con su contrasena. Se actualizan el CI, el complemento y la fecha leidos de ellas.
     */
    public UsuarioResponse reemplazarPorConductor(Long idUsuario, CarnetRequest datos, MultipartFile anverso,
            MultipartFile reverso) {
        FotosCarnet fotos = validar(anverso, reverso);
        verificarLectura(fotos, datos);
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new CredencialesInvalidasException("Credenciales invalidas"));
        cuentaUsuarioService.confirmarContrasena(usuario, datos.password());
        Conductor conductor = conductorRepository.findByUsuarioId(idUsuario)
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de conductor"));
        permisoEdicionService.consumir(conductor.getId(), TipoPermisoEdicion.CARNET, null);
        Persona persona = usuario.getPersona();
        actualizarDatos(persona, datos);
        guardar(persona, fotos);
        return UsuarioResponse.de(usuario);
    }

    /** El administrador cambia una o las dos fotos del carnet de la persona de una cuenta. */
    public void reemplazarPorAdmin(Long idUsuario, MultipartFile anverso, MultipartFile reverso) {
        boolean conAnverso = anverso != null && !anverso.isEmpty();
        boolean conReverso = reverso != null && !reverso.isEmpty();
        if (!conAnverso && !conReverso) {
            throw new NegocioException("Elija al menos una foto del carnet");
        }
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", idUsuario));
        Persona persona = usuario.getPersona();
        String carpeta = almacenamientoArchivos.carpetaCarnet(persona);
        if (conAnverso) {
            persona.setCarnetAnversoUrl(almacenamientoArchivos.reemplazarConSello(persona.getCarnetAnversoUrl(),
                    procesar(anverso, "anverso"), carpeta,
                    "carnet_anverso", "jpg"));
        }
        if (conReverso) {
            persona.setCarnetReversoUrl(almacenamientoArchivos.reemplazarConSello(persona.getCarnetReversoUrl(),
                    procesar(reverso, "reverso"), carpeta,
                    "carnet_reverso", "jpg"));
        }
    }

    /** Datos leidos del carnet: CI (unico), complemento, nombre impreso y fecha de nacimiento. */
    public void actualizarDatos(Persona persona, CarnetRequest datos) {
        // Valida el CI unico igual que el panel admin.
        gestionPersonaService.actualizar(persona.getId(), new PersonaRequest(
                datos.ci().trim(),
                vacioANull(datos.complementoCi()),
                ReglasRegistro.nombreOActual(datos.nombres(), persona.getNombres()),
                ReglasRegistro.nombreOActual(datos.apellidos(), persona.getApellidos()),
                datos.fechaNacimiento(),
                persona.getCorreo(),
                persona.getTelefono()));
    }

    public FotosCarnet validar(MultipartFile anverso, MultipartFile reverso) {
        return new FotosCarnet(procesar(anverso, "anverso"), procesar(reverso, "reverso"),
                LecturaDocumentoService.huella(anverso), LecturaDocumentoService.huella(reverso));
    }

    /** Guarda las fotos en personas/<id>_<ci>/general/carnet y deja sus rutas en la persona. */
    public void guardar(Persona persona, FotosCarnet fotos) {
        String carpeta = almacenamientoArchivos.carpetaCarnet(persona);
        persona.setCarnetAnversoUrl(almacenamientoArchivos.reemplazarConSello(persona.getCarnetAnversoUrl(),
                fotos.anverso(), carpeta, "carnet_anverso", "jpg"));
        persona.setCarnetReversoUrl(almacenamientoArchivos.reemplazarConSello(persona.getCarnetReversoUrl(),
                fotos.reverso(), carpeta, "carnet_reverso", "jpg"));
    }

    /**
     * Foto del carnet de la persona de una cuenta ("anverso" o "reverso"), solo para el panel admin.
     * 404 si no la tiene.
     */
    @Transactional(readOnly = true)
    public Resource leer(Long idUsuario, String lado) {
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", idUsuario));
        Persona persona = usuario.getPersona();
        String ruta = switch (lado) {
            case "anverso" -> persona.getCarnetAnversoUrl();
            case "reverso" -> persona.getCarnetReversoUrl();
            default -> throw new NegocioException("Lado del carnet no valido: " + lado);
        };
        if (ruta == null || !almacenamientoArchivos.existe(ruta)) {
            throw new RecursoNoEncontradoException("La persona no registro la foto del " + lado + " de su carnet");
        }
        return almacenamientoArchivos.leer(ruta);
    }

    private static byte[] procesar(MultipartFile foto, String lado) {
        return procesarFoto(foto, lado, "carnet");
    }

    /** Foto de un documento (carnet o licencia) lista para guardar: JPEG de hasta 1600 px. */
    public static byte[] procesarFoto(MultipartFile foto, String lado, String documento) {
        if (foto == null || foto.isEmpty()) {
            throw new NegocioException("Falta la foto del " + lado + " de tu " + documento);
        }
        if (foto.getSize() > AlmacenamientoArchivos.TAMANO_MAXIMO_IMAGEN * 2) {
            throw new NegocioException("La foto del " + lado + " de tu " + documento + " supera los 10 MB");
        }
        try {
            return ProcesadorImagen.imagenCarnet(foto.getBytes());
        } catch (IOException | IllegalArgumentException | IllegalStateException e) {
            throw new NegocioException("No se pudo leer la foto del " + lado + " de tu " + documento);
        }
    }

    private static String vacioANull(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim().toUpperCase();
    }
}
