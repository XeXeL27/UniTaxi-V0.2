package com.taxiuap.backend.identity.service;

import java.io.IOException;
import java.util.Map;

import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.CarnetRequest;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.dto.UsuarioResponse;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
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

    private final UsuarioRepository usuarioRepository;
    private final GestionPersonaService gestionPersonaService;
    private final AlmacenamientoArchivos almacenamientoArchivos;
    private final CredencialesCorreoService credencialesCorreoService;

    /** Partes del multipart del registro de conductor que son fotos del carnet (no PDF). */
    public static boolean esParteCarnet(String parte) {
        return PARTE_ANVERSO.equals(parte) || PARTE_REVERSO.equals(parte);
    }

    /** Fotos del carnet ya procesadas (JPEG), listas para guardar. */
    public record FotosCarnet(byte[] anverso, byte[] reverso) {
    }

    /** Pantalla "Verifica tu carnet" de la app: guarda los datos y las fotos de la persona. */
    public UsuarioResponse registrar(Long idUsuario, CarnetRequest datos, MultipartFile anverso, MultipartFile reverso) {
        FotosCarnet fotos = validar(anverso, reverso);
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new CredencialesInvalidasException("Credenciales invalidas"));
        Persona persona = usuario.getPersona();
        // Valida el CI unico igual que el panel admin.
        gestionPersonaService.actualizar(persona.getId(), new PersonaRequest(
                datos.ci().trim(),
                vacioANull(datos.complementoCi()),
                persona.getNombres(),
                persona.getApellidos(),
                datos.fechaNacimiento(),
                persona.getCorreo(),
                persona.getTelefono()));
        guardar(persona, fotos);
        entregarCredenciales(usuario);
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

    /** Fotos del carnet que llegan en un multipart (registro de conductor con Google): obligatorias. */
    public FotosCarnet validarDelRegistro(Map<String, MultipartFile> archivos) {
        return validar(archivos.get(PARTE_ANVERSO), archivos.get(PARTE_REVERSO));
    }

    public FotosCarnet validar(MultipartFile anverso, MultipartFile reverso) {
        return new FotosCarnet(procesar(anverso, "anverso"), procesar(reverso, "reverso"));
    }

    /** Guarda las fotos en personas/<id>_<ci>/general/carnet y deja sus rutas en la persona. */
    public void guardar(Persona persona, FotosCarnet fotos) {
        String carpeta = almacenamientoArchivos.carpetaCarnet(persona);
        persona.setCarnetAnversoUrl(almacenamientoArchivos.guardarConSello(fotos.anverso(), carpeta, "carnet_anverso", "jpg"));
        persona.setCarnetReversoUrl(almacenamientoArchivos.guardarConSello(fotos.reverso(), carpeta, "carnet_reverso", "jpg"));
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
        if (foto == null || foto.isEmpty()) {
            throw new NegocioException("Falta la foto del " + lado + " de tu carnet");
        }
        if (foto.getSize() > AlmacenamientoArchivos.TAMANO_MAXIMO_IMAGEN * 2) {
            throw new NegocioException("La foto del " + lado + " del carnet supera los 10 MB");
        }
        try {
            return ProcesadorImagen.imagenCarnet(foto.getBytes());
        } catch (IOException e) {
            throw new NegocioException("No se pudo leer la foto del " + lado + " del carnet");
        }
    }

    private static String vacioANull(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim().toUpperCase();
    }
}
