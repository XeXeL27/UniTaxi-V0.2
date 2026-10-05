package com.taxiuap.backend.identity.service;

import java.util.List;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.CarnetRequest;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.dto.RegistroEstudianteUapRequest;
import com.taxiuap.backend.identity.dto.RegistroEstudianteUapResponse;
import com.taxiuap.backend.identity.dto.ReglasRegistro;
import com.taxiuap.backend.identity.dto.TokenResponse;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.institution.dto.DatosSigse;
import com.taxiuap.backend.institution.dto.DatosSigseAdminResponse;
import com.taxiuap.backend.institution.dto.EstadoEstudianteResponse;
import com.taxiuap.backend.institution.enums.SituacionVerificacion;
import com.taxiuap.backend.institution.service.EstudianteUapService;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.ConflictoException;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/**
 * Registro y verificacion de estudiantes de la UAP con el SIGSE.
 *
 * Registro nuevo (app, Crear cuenta > Estudiante UAP): la persona escribe su RU; si el SIGSE dice que
 * esta matriculado, toma las fotos de su carnet y el servidor compara nombre, CI y fecha de
 * nacimiento con el SIGSE. Si coinciden se crea su cuenta de pasajero como estudiante (con la foto del
 * SIGSE) y las credenciales van al correo que tiene la UAP. Si algo no coincide puede marcar
 * "Observado": el administrador lo revisa en Carnets observados y lo aprueba como estudiante o como
 * pasajero normal; recien entonces le llegan las credenciales.
 *
 * Quien ya tiene cuenta: con el mismo RU (desde el registro, el Perfil de la app o el panel) queda
 * marcado como estudiante si sus datos guardados coinciden con el SIGSE.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RegistroEstudianteUapService {

    private final EstudianteUapService estudianteUapService;
    private final ConsultaRuTemporal temporal;
    private final PersonaRepository personaRepository;
    private final UsuarioRepository usuarioRepository;
    private final PasajeroRepository pasajeroRepository;
    private final GestionPersonaService gestionPersonaService;
    private final CarnetService carnetService;
    private final RegistroGoogleService registroGoogleService;
    private final FotoPerfilService fotoPerfilService;

    /**
     * Paso 1 del registro: el RU. Si la persona ya tiene cuenta de pasajero y sus datos coinciden con
     * el SIGSE, queda como estudiante en ese momento (no hace falta registrarse de nuevo).
     */
    @Transactional
    public RegistroEstudianteUapResponse consultar(String ru, String ip) {
        temporal.controlarLimite(ip);
        DatosSigse sigse = estudianteUapService.consultarMatriculado(ru);
        if (sigse.ci() == null || sigse.fechaNacimiento() == null) {
            throw new NegocioException("La UAP no tiene completos tus datos (CI o fecha de nacimiento). "
                    + "Acércate a un administrador de UNITAXI.");
        }
        String nombre = sigse.nombreCompleto();

        Optional<Persona> existente = personaPorCi(sigse.ci());
        Optional<Usuario> pasajero = existente.flatMap(p -> cuenta(p, RolSistema.PASAJERO));
        if (pasajero.isPresent()) {
            Persona persona = existente.get();
            List<String> distintos = EstudianteUapService.diferencias(sigse, persona);
            if (!distintos.isEmpty()) {
                return new RegistroEstudianteUapResponse(null, nombre, sigse.carrera(), ocultar(persona.getCorreo()), true,
                        "Ya tienes una cuenta en UNITAXI con ese carnet, pero " + EstudianteUapService.enFrase(distintos)
                                + " no coincide con la UAP. Ingresa y pide la verificación a un administrador.");
            }
            estudianteUapService.marcarEstudiante(persona, sigse, SituacionVerificacion.APROBADA);
            fotoSiNoTiene(pasajero.get(), sigse.foto());
            return new RegistroEstudianteUapResponse(null, nombre, sigse.carrera(), ocultar(persona.getCorreo()), true,
                    "Ya tenías una cuenta en UNITAXI: quedaste registrado como estudiante UAP. "
                            + "Ingresa con tu usuario y contraseña de siempre.");
        }
        if (existente.isEmpty()) {
            if (sigse.correo() == null) {
                throw new NegocioException("La UAP no tiene un correo registrado para ti y lo necesitamos para "
                        + "enviarte tus credenciales. Acércate a un administrador de UNITAXI.");
            }
            if (personaRepository.findByCorreo(sigse.correo()).isPresent()) {
                throw new ConflictoException("El correo que tiene la UAP para ti ya está usado en otra cuenta de "
                        + "UNITAXI. Acércate a un administrador.");
            }
        }
        String correo = existente.map(Persona::getCorreo).orElse(sigse.correo());
        return new RegistroEstudianteUapResponse(temporal.guardar(sigse), nombre, sigse.carrera(), ocultar(correo),
                false, null);
    }

    /**
     * Paso 2: las fotos del carnet. Sin "Observado" los datos del carnet deben ser los que se leyeron de
     * las fotos y los del SIGSE. Todo se guarda junto: si algo falla no queda nada.
     */
    @Transactional
    public TokenResponse registrar(RegistroEstudianteUapRequest datos, MultipartFile anverso, MultipartFile reverso) {
        DatosSigse sigse = temporal.ver(datos.codigo())
                .orElseThrow(() -> new NegocioException("La consulta de tu RU venció. Vuelve a escribir tu RU."));
        CarnetRequest carnet = datos.carnet();
        CarnetService.FotosCarnet fotos = carnetService.validar(anverso, reverso);
        if (!carnet.esObservado()) {
            carnetService.verificarLectura(fotos, carnet.ci(), carnet.complementoCi(), carnet.fechaNacimiento(),
                    carnet.nombres(), carnet.apellidos());
            List<String> distintos = EstudianteUapService.diferencias(sigse, carnet.ci(), carnet.fechaNacimiento(),
                    carnet.nombres(), carnet.apellidos());
            if (!distintos.isEmpty()) {
                throw new NegocioException("Los datos de tu carnet no coinciden con los de la UAP ("
                        + EstudianteUapService.enFrase(distintos) + "). Vuelve a tomar las fotos o elige "
                        + "\"Observado\" para que un administrador lo revise.");
            }
        }

        Optional<Persona> existente = personaPorCi(sigse.ci());
        if (existente.isPresent() && cuenta(existente.get(), RolSistema.PASAJERO).isPresent()) {
            throw new ConflictoException("Ya tienes una cuenta de pasajero: ingresa con tu usuario de siempre");
        }
        Persona persona;
        if (existente.isPresent()) {
            persona = existente.get();
            carnetService.actualizarDatos(persona, carnet);
        } else {
            String telefono = sigse.celularValido() != null && !personaRepository.existsByTelefono(sigse.celularValido())
                    ? sigse.celularValido() : null;
            persona = gestionPersonaService.registrarEntidad(new PersonaRequest(carnet.ci().trim(),
                    vacioANull(carnet.complementoCi()),
                    ReglasRegistro.nombreOActual(carnet.nombres(), sigse.nombres()),
                    ReglasRegistro.nombreOActual(carnet.apellidos(), sigse.apellidos()),
                    carnet.fechaNacimiento(), sigse.correo(), telefono));
        }
        carnetService.guardar(persona, fotos);
        boolean observado = carnetService.revisar(persona, carnet.esObservado(), carnet.aceptoTerminos());
        estudianteUapService.marcarEstudiante(persona, sigse,
                observado ? SituacionVerificacion.PENDIENTE : SituacionVerificacion.APROBADA);
        TokenResponse tokens = registroGoogleService.crearPasajero(persona, sigse.foto(), !observado);
        temporal.terminar(datos.codigo());
        return tokens;
    }

    /** Perfil de la app: "Soy estudiante UAP". Se compara el SIGSE con los datos de su carnet ya guardado. */
    @Transactional
    public EstadoEstudianteResponse verificarCuenta(Long idUsuario, String ru) {
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", idUsuario));
        return verificar(usuario, ru, "Tus datos no coinciden con los de la UAP");
    }

    /** Situacion de estudiante de la cuenta; si su matricula vencio se vuelve a consultar el SIGSE. */
    @Transactional
    public EstadoEstudianteResponse estadoCuenta(Long idUsuario) {
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", idUsuario));
        return estudianteUapService.renovarSiVencio(usuario.getPersona());
    }

    /** Panel: "Verificar con SIGSE" en un pasajero. Sin RU usa el que ya tenia registrado. */
    @Transactional
    public EstadoEstudianteResponse verificarPorAdmin(Long idPasajero, String ru) {
        Pasajero pasajero = pasajeroRepository.findById(idPasajero)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Pasajero", idPasajero));
        String numero = ru != null && !ru.isBlank() ? ru
                : estudianteUapService.estado(pasajero.getUsuario().getPersona()).ru();
        if (numero == null) throw new NegocioException("Escribe el RU del pasajero");
        return verificar(pasajero.getUsuario(), numero, "Los datos del pasajero no coinciden con la UAP");
    }

    /** Lo que dice el SIGSE de un RU, para el administrador. */
    public DatosSigseAdminResponse sigseParaAdmin(String ru) {
        return DatosSigseAdminResponse.de(estudianteUapService.consultar(ru));
    }

    private EstadoEstudianteResponse verificar(Usuario usuario, String ru, String mensajeDistinto) {
        Persona persona = usuario.getPersona();
        if (persona.getCi() == null || persona.getCi().isBlank()) {
            throw new NegocioException("Primero registra tu carnet en UNITAXI");
        }
        DatosSigse sigse = estudianteUapService.consultarMatriculado(ru);
        List<String> distintos = EstudianteUapService.diferencias(sigse, persona);
        if (!distintos.isEmpty()) {
            throw new NegocioException(mensajeDistinto + " (" + EstudianteUapService.enFrase(distintos) + ").");
        }
        // Solo cambia su estado de estudiante; sus datos ya estaban validados con su carnet.
        estudianteUapService.marcarEstudiante(persona, sigse, SituacionVerificacion.APROBADA);
        boolean conFoto = cuenta(persona, RolSistema.PASAJERO).map(p -> fotoSiNoTiene(p, sigse.foto())).orElse(false);
        return estudianteUapService.estado(persona).conFotoDelSigse(conFoto);
    }

    /**
     * La foto del SIGSE solo se pone si la cuenta no tiene foto de perfil: la que subio la persona (o la
     * de Google) se respeta. Devuelve true si se guardo la del SIGSE.
     */
    private boolean fotoSiNoTiene(Usuario cuenta, byte[] fotoSigse) {
        if (!usarFotoSigse(cuenta.getFotoUrl(), fotoSigse)) return false;
        fotoPerfilService.guardarImagen(cuenta, fotoSigse);
        return cuenta.getFotoUrl() != null;
    }

    static boolean usarFotoSigse(String fotoActual, byte[] fotoSigse) {
        return fotoSigse != null && (fotoActual == null || fotoActual.isBlank());
    }

    // ------------------------------------------------------------------ apoyo

    private Optional<Persona> personaPorCi(String ci) {
        return personaRepository.findByCiAndEstadoPersona(ci.trim(), EstadoRegistro.A).stream().findFirst();
    }

    private Optional<Usuario> cuenta(Persona persona, RolSistema rol) {
        return usuarioRepository.findByPersonaIdAndRolCodigo(persona.getId(), rol.getCodigo())
                .filter(u -> u.getEstadoUsuario() != EstadoRegistro.X);
    }

    /** "duryaxel27@gmail.com" -> "du***@gmail.com". */
    static String ocultar(String correo) {
        if (correo == null || !correo.contains("@")) return null;
        String usuario = correo.substring(0, correo.indexOf('@'));
        return usuario.substring(0, Math.min(2, usuario.length())) + "***" + correo.substring(correo.indexOf('@'));
    }

    private static String vacioANull(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }
}
