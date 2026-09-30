package com.taxiuap.backend.identity.service;

import java.io.IOException;
import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

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
        return UsuarioResponse.de(usuario);
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
