package com.taxiuap.backend.identity.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.dto.RegistroPersonaAdminRequest;
import com.taxiuap.backend.identity.dto.RegistroPersonaAdminResponse;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.SituacionCarnet;
import com.taxiuap.backend.identity.enums.TipoRegistroPersona;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.institution.dto.DatosSigse;
import com.taxiuap.backend.institution.enums.SituacionVerificacion;
import com.taxiuap.backend.institution.service.EstudianteUapService;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.extern.slf4j.Slf4j;

/**
 * Personas > Registrar persona: el administrador escribe los datos de una persona (externa o estudiante
 * de la UAP) y se crea su cuenta de pasajero con credenciales que le llegan al correo. Estudiante solo si
 * el SIGSE confirma el RU (matriculado) y que el nombre, el carnet y la fecha son los mismos; si el SIGSE
 * no responde no se registra como estudiante.
 *
 * Las fotos del carnet son opcionales: con anverso, reverso y la foto con el carnet queda verificada;
 * sin ellas, al ingresar por primera vez la app le pide confirmar sus datos con las fotos (como a las
 * cuentas que ya usaban la app), con el plazo de taxiuap.selfie.dias-plazo dias antes de suspenderse.
 */
@Slf4j
@Service
@Transactional
public class RegistroPersonaAdminService {

    private final GestionPersonaService gestionPersonaService;
    private final PersonaRepository personaRepository;
    private final CuentaUsuarioService cuentaUsuarioService;
    private final CredencialesCorreoService credencialesCorreoService;
    private final CarnetService carnetService;
    private final EstudianteUapService estudianteUapService;
    private final FotoPerfilService fotoPerfilService;
    private final int diasPlazo;

    public RegistroPersonaAdminService(GestionPersonaService gestionPersonaService, PersonaRepository personaRepository,
            CuentaUsuarioService cuentaUsuarioService, CredencialesCorreoService credencialesCorreoService,
            CarnetService carnetService, EstudianteUapService estudianteUapService, FotoPerfilService fotoPerfilService,
            @Value("${taxiuap.selfie.dias-plazo:7}") int diasPlazo) {
        this.gestionPersonaService = gestionPersonaService;
        this.personaRepository = personaRepository;
        this.cuentaUsuarioService = cuentaUsuarioService;
        this.credencialesCorreoService = credencialesCorreoService;
        this.carnetService = carnetService;
        this.estudianteUapService = estudianteUapService;
        this.fotoPerfilService = fotoPerfilService;
        this.diasPlazo = diasPlazo;
    }

    public RegistroPersonaAdminResponse registrar(RegistroPersonaAdminRequest datos, MultipartFile anverso,
            MultipartFile reverso, MultipartFile selfie) {
        boolean conAnverso = conArchivo(anverso);
        boolean conReverso = conArchivo(reverso);
        boolean conSelfie = conArchivo(selfie);
        if ((conAnverso || conReverso || conSelfie) && !(conAnverso && conReverso)) {
            throw new NegocioException("Para subir las fotos del carnet elige el anverso y el reverso "
                    + "(la foto con el carnet es opcional)");
        }
        if (datos.carnetVencimiento() != null && datos.carnetVencimiento().isBefore(LocalDate.now())) {
            throw new NegocioException("El carnet está vencido: la persona debe renovarlo antes de registrarse");
        }
        boolean estudiante = datos.tipo() == TipoRegistroPersona.ESTUDIANTE_UAP;
        // El SIGSE se consulta antes de crear nada: sin su confirmacion no se registra como estudiante.
        DatosSigse sigse = estudiante ? confirmarConSigse(datos) : null;

        Long idPersona = gestionPersonaService.crear(new PersonaRequest(datos.ci().trim(),
                vacioANull(datos.complementoCi()), datos.nombres(), datos.apellidos(), datos.fechaNacimiento(),
                datos.correo(), datos.telefono())).idPersona();
        Persona persona = personaRepository.findById(idPersona)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Persona", idPersona));
        persona.setCarnetVencimiento(datos.carnetVencimiento());

        String contrasena = CredencialesCorreoService.contrasenaLegible();
        Usuario usuario = cuentaUsuarioService.crearUsuario(persona, RolSistema.PASAJERO,
                cuentaUsuarioService.nombreUsuarioLibre(persona.getCorreo()), cuentaUsuarioService.codificar(contrasena));
        usuario.setContrasenaGenerada(true);
        cuentaUsuarioService.crearPasajero(usuario);

        if (sigse != null) {
            estudianteUapService.marcarEstudiante(persona, sigse, SituacionVerificacion.APROBADA);
            if (sigse.foto() != null) fotoPerfilService.guardarImagen(usuario, sigse.foto());
        }
        if (conAnverso) {
            // Las sube el administrador: quedan como verificadas (no pasan por la lectura con IA).
            carnetService.reemplazarPorAdmin(usuario.getId(), anverso, reverso, conSelfie ? selfie : null);
            persona.setSituacionCarnet(SituacionCarnet.VERIFICADO);
        }
        if (!conSelfie) {
            persona.setSelfieExigida(true);
            persona.setPlazoSelfieCarnet(LocalDateTime.now().plusDays(diasPlazo));
        }
        String pendiente = conSelfie ? null : conAnverso ? "SELFIE" : "CARNET";
        credencialesCorreoService.registradoPorAdmin(usuario, contrasena, estudiante, pendiente);
        log.info("Persona {} registrada desde el panel como {} (cuenta {}, falta del carnet: {})", persona.getId(),
                datos.tipo(), usuario.getNombreUsuario(), pendiente);
        return new RegistroPersonaAdminResponse(persona.getId(), usuario.getId(),
                persona.getNombres() + " " + persona.getApellidos(), usuario.getNombreUsuario(), persona.getCorreo(),
                estudiante, sigse == null ? null : sigse.carrera(), pendiente);
    }

    private DatosSigse confirmarConSigse(RegistroPersonaAdminRequest datos) {
        if (datos.ru() == null || datos.ru().isBlank()) {
            throw new NegocioException("Escribe el RU del estudiante");
        }
        DatosSigse sigse = estudianteUapService.consultarMatriculado(datos.ru().trim());
        List<String> distintos = EstudianteUapService.diferencias(sigse, datos.ci(), datos.fechaNacimiento(),
                datos.nombres(), datos.apellidos());
        if (!distintos.isEmpty()) {
            throw new NegocioException("El SIGSE no confirma los datos escritos: no coinciden "
                    + EstudianteUapService.enFrase(distintos).replace("tu ", "el ").replace("el fecha", "la fecha")
                    + ". Usa Consultar SIGSE o regístralo como persona externa.");
        }
        return sigse;
    }

    private static boolean conArchivo(MultipartFile archivo) {
        return archivo != null && !archivo.isEmpty();
    }

    private static String vacioANull(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }
}
