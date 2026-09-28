package com.taxiuap.backend.identity.service;


import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.config.security.JwtService;
import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.config.security.TipoToken;
import com.taxiuap.backend.identity.dto.LoginRequest;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.dto.RefreshRequest;
import com.taxiuap.backend.identity.dto.RegistroConductorRequest;
import com.taxiuap.backend.identity.dto.RegistroPasajeroRequest;
import com.taxiuap.backend.identity.dto.TokenResponse;
import com.taxiuap.backend.identity.dto.UsuarioResponse;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.CredencialesInvalidasException;
import com.taxiuap.backend.shared.exception.NegocioException;

import io.jsonwebtoken.JwtException;
import lombok.RequiredArgsConstructor;

import java.util.*;

import static com.taxiuap.backend.identity.service.CuentaUsuarioService.normalizarNombreUsuario;

/** Registro publico (desde la app), inicio de sesion y renovacion de tokens. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AutenticacionService {

    private static final String MENSAJE_CREDENCIALES_INVALIDAS = "Credenciales invalidas";

    private final PersonaRepository personaRepository;
    private final UsuarioRepository usuarioRepository;
    private final GestionPersonaService gestionPersonaService;
    private final CuentaUsuarioService cuentaUsuarioService;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    @Transactional
    public TokenResponse registrarPasajero(RegistroPasajeroRequest datos) {
        validarContacto(datos.correo(), datos.telefono());
        String nombreUsuario = normalizarNombreUsuario(datos.nombreUsuario());
        cuentaUsuarioService.validarNombreUsuarioDisponible(nombreUsuario, null);

        Persona persona = gestionPersonaService.registrarEntidad(new PersonaRequest(datos.ci(), datos.complementoCi(),
                datos.nombres(), datos.apellidos(), datos.fechaNacimiento(), datos.correo(), datos.telefono()));
        Usuario usuario = cuentaUsuarioService.crearUsuario(persona, RolSistema.PASAJERO, nombreUsuario,
                cuentaUsuarioService.codificar(datos.password()));
        cuentaUsuarioService.crearPasajero(usuario);

        return generarTokens(usuario);
    }

    @Transactional
    public TokenResponse registrarConductor(RegistroConductorRequest datos) {
        validarContacto(datos.correo(), datos.telefono());
        String nombreUsuario = normalizarNombreUsuario(datos.nombreUsuario());
        cuentaUsuarioService.validarNombreUsuarioDisponible(nombreUsuario, null);

        Persona persona = gestionPersonaService.registrarEntidad(new PersonaRequest(datos.ci(), datos.complementoCi(),
                datos.nombres(), datos.apellidos(), datos.fechaNacimiento(), datos.correo(), datos.telefono()));
        Usuario usuario = cuentaUsuarioService.crearUsuario(persona, RolSistema.CONDUCTOR, nombreUsuario,
                cuentaUsuarioService.codificar(datos.password()));
        cuentaUsuarioService.crearConductor(usuario, datos.numeroLicencia(), datos.categoriaLicencia());

        return generarTokens(usuario);
    }

    /**
     * El identificador puede ser nombre de usuario, correo o telefono. Si con esas credenciales hay
     * mas de una cuenta (la misma persona como pasajero y conductor) hace falta indicar el rol.
     */
    public TokenResponse login(LoginRequest datos) {
        List<Usuario> candidatos = buscarCandidatos(datos.usuario().trim()).stream()
                .filter(u -> u.getEstadoUsuario() == EstadoRegistro.A)
                .filter(u -> u.getPersona().getEstadoPersona() == EstadoRegistro.A)
                .filter(u -> datos.rol() == null || datos.rol().isBlank()
                        || u.getRol().getCodigo().equalsIgnoreCase(datos.rol().trim()))
                .filter(u -> passwordEncoder.matches(datos.password(), u.getPasswordHash()))
                .toList();

        if (candidatos.isEmpty()) {
            throw new CredencialesInvalidasException(MENSAJE_CREDENCIALES_INVALIDAS);
        }
        if (candidatos.size() > 1) {
            throw new NegocioException("La cuenta tiene mas de un tipo de usuario: indique el rol con que ingresa");
        }
        return generarTokens(candidatos.get(0));
    }

    /**
     * Roles de las cuentas que coinciden con estas credenciales, sin iniciar sesion. La app movil lo
     * usa para saber si la persona entra como pasajero, como conductor o si hay que preguntarle.
     */
    public List<String> cuentas(String identificador, String password) {
        List<String> roles = buscarCandidatos(identificador.trim()).stream()
                .filter(u -> u.getEstadoUsuario() == EstadoRegistro.A)
                .filter(u -> u.getPersona().getEstadoPersona() == EstadoRegistro.A)
                .filter(u -> passwordEncoder.matches(password, u.getPasswordHash()))
                .map(u -> u.getRol().getCodigo())
                .distinct()
                .toList();
        if (roles.isEmpty()) {
            throw new CredencialesInvalidasException(MENSAJE_CREDENCIALES_INVALIDAS);
        }
        return roles;
    }

    /**
     * Pasa la sesion a la otra cuenta de la misma persona (pasajero o conductor) sin volver a pedir
     * la contrasena: las dos cuentas comparten credenciales y la persona ya se autentico.
     */
    public TokenResponse cambiarRol(Long idUsuarioActual, String rol) {
        Usuario actual = usuarioRepository.findById(idUsuarioActual)
                .orElseThrow(() -> new CredencialesInvalidasException(MENSAJE_CREDENCIALES_INVALIDAS));
        String destino = rol == null ? "" : rol.trim().toUpperCase();
        if (!RolSistema.PASAJERO.getCodigo().equals(destino) && !RolSistema.CONDUCTOR.getCodigo().equals(destino)) {
            throw new NegocioException("Solo se puede cambiar entre pasajero y conductor");
        }
        return usuarioRepository.findByPersonaId(actual.getPersona().getId()).stream()
                .filter(u -> u.getEstadoUsuario() == EstadoRegistro.A)
                .filter(u -> u.getRol().getCodigo().equals(destino))
                .findFirst()
                .map(this::generarTokens)
                .orElseThrow(() -> new NegocioException("No tiene una cuenta de " + destino.toLowerCase()));
    }

    public TokenResponse refrescar(RefreshRequest datos) {
        try {
            var jwtUser = jwtService.validar(datos.tokenRefresco(), TipoToken.REFRESCO);
            Usuario usuario = usuarioRepository.findById(jwtUser.idUsuario())
                    .orElseThrow(() -> new CredencialesInvalidasException(MENSAJE_CREDENCIALES_INVALIDAS));

            if (usuario.getEstadoUsuario() != EstadoRegistro.A
                    || usuario.getPersona().getEstadoPersona() != EstadoRegistro.A) {
                throw new NegocioException("La cuenta no esta activa");
            }

            return generarTokens(usuario);
        } catch (JwtException e) {
            throw new CredencialesInvalidasException(MENSAJE_CREDENCIALES_INVALIDAS);
        }
    }

    private List<Usuario> buscarCandidatos(String identificador) {
        Map<Long, Usuario> candidatos = new LinkedHashMap<>();
        usuarioRepository.findByNombreUsuario(normalizarNombreUsuario(identificador))
                .forEach(u -> candidatos.put(u.getId(), u));

        List<Persona> personas = new ArrayList<>();
        personaRepository.findByCorreo(identificador.toLowerCase()).ifPresent(personas::add);
        personaRepository.findByTelefono(identificador).ifPresent(personas::add);
        for (Persona persona : personas) {
            usuarioRepository.findByPersonaId(persona.getId()).forEach(u -> candidatos.put(u.getId(), u));
        }
        return new ArrayList<>(candidatos.values());
    }

    private void validarContacto(String correo, String telefono) {
        boolean tieneCorreo = correo != null && !correo.isBlank();
        boolean tieneTelefono = telefono != null && !telefono.isBlank();
        if (!tieneCorreo && !tieneTelefono) {
            throw new NegocioException("Debe indicar un correo o un telefono");
        }
    }

    private TokenResponse generarTokens(Usuario usuario) {
        String sujeto = usuario.getNombreUsuario();
        String rolCodigo = usuario.getRol().getCodigo();

        String tokenAcceso = jwtService.generarAcceso(usuario.getId(), sujeto, rolCodigo);
        String tokenRefresco = jwtService.generarRefresco(usuario.getId(), sujeto, rolCodigo);

        Persona persona = usuario.getPersona();
        UsuarioResponse usuarioResponse = new UsuarioResponse(
                usuario.getId(),
                usuario.getNombreUsuario(),
                persona.getNombres(),
                persona.getApellidos(),
                persona.getCorreo(),
                persona.getTelefono(),
                rolCodigo);

        List<String> rolesDisponibles = usuarioRepository.findByPersonaId(persona.getId()).stream()
                .filter(u -> u.getEstadoUsuario() == EstadoRegistro.A)
                .map(u -> u.getRol().getCodigo())
                .distinct()
                .toList();

        return new TokenResponse(tokenAcceso, tokenRefresco, jwtService.getExpiracionMs(), usuarioResponse,
                rolesDisponibles);
    }
    /**
     * Inicio de sesion con Google OAuth2.
     * Si el usuario no existe, lo crea con rol PASAJERO por defecto.
     * Si ya existe, valida que la cuenta este activa y emite tokens.
     */
    @Transactional
    public TokenResponse loginConGoogle(String email, String nombre, String picture) {
        // Buscar usuario por correo electronico (el username normalizado)
        String nombreUsuario = normalizarNombreUsuario(email);

        // Verificar si ya existe una cuenta con este correo
        List<Usuario> usuariosConEsteCorreo = usuarioRepository.findByNombreUsuario(nombreUsuario);
        boolean usuarioExiste = !usuariosConEsteCorreo.isEmpty();

        if (usuarioExiste) {
            Usuario usuario = usuariosConEsteCorreo.get(0);
            // Validar que la cuenta y persona esten activas
            if (usuario.getEstadoUsuario() != EstadoRegistro.A
                    || usuario.getPersona().getEstadoPersona() != EstadoRegistro.A) {
                throw new NegocioException("La cuenta no esta activa");
            }
            return generarTokens(usuario);
        }

        // Buscar persona existente con este correo (puede tener cuenta de otro rol)
        Optional<Persona> optionalPersona = personaRepository.findByCorreo(email.toLowerCase());

        if (optionalPersona.isPresent()) {
            Persona persona = optionalPersona.get();
            // Verificar si ya tiene una cuenta de pasajero
            if (usuarioRepository.existsByPersonaIdAndRolCodigoAndEstadoUsuario(
                    persona.getId(), RolSistema.PASAJERO.getCodigo(), EstadoRegistro.A)) {
                // Ya tiene cuenta de pasajero, obtenerla
                Usuario usuario = usuarioRepository.findByPersonaIdAndRolCodigo(
                                persona.getId(), RolSistema.PASAJERO.getCodigo())
                        .orElseThrow();
                return generarTokens(usuario);
            }
            // La persona existe pero tiene otro rol (conductor, admin), lanzar error o crear pasajero
            throw new NegocioException("Esta persona ya tiene una cuenta con otro rol");
        }

        // Crear nueva persona con datos de Google. Google entrega el nombre completo en
        // un solo campo: se reparte entre nombres y apellidos (los dos obligatorios).
        // Con tres o mas palabras se toman las dos ultimas como apellidos (uso boliviano).
        String[] partesNombre = nombre != null ? nombre.trim().split("\\s+") : new String[0];
        String nombres;
        String apellidos;
        if (partesNombre.length == 0) {
            nombres = "Usuario";
            apellidos = "Google";
        } else if (partesNombre.length == 1) {
            nombres = partesNombre[0];
            apellidos = "Sin especificar";
        } else if (partesNombre.length == 2) {
            nombres = partesNombre[0];
            apellidos = partesNombre[1];
        } else {
            nombres = String.join(" ", java.util.Arrays.copyOf(partesNombre, partesNombre.length - 2));
            apellidos = partesNombre[partesNombre.length - 2] + " " + partesNombre[partesNombre.length - 1];
        }

        Persona nuevaPersona = new Persona();
        nuevaPersona.setCorreo(email.toLowerCase());
        nuevaPersona.setNombres(nombres);
        nuevaPersona.setApellidos(apellidos);
        // El CI y el telefono no vienen de Google: van null (la columna es unica y admite
        // varios null; un valor vacio repetido violaria la restriccion con el segundo usuario).
        nuevaPersona.setCi(null);
        nuevaPersona.setComplementoCi(null);
        nuevaPersona.setTelefono(null);
        nuevaPersona.setFechaNacimiento(null);
        personaRepository.save(nuevaPersona);

        // Crear usuario con rol PASAJERO
        String nombreUsuarioUnico = nombreUsuario;
        // Verificar que el nombre de usuario no exista (aunque el correo sea unico)
        if (!usuarioRepository.findByNombreUsuario(nombreUsuarioUnico).isEmpty()) {
            // Agregar un sufijo para hacer unico
            nombreUsuarioUnico = nombreUsuarioUnico + "@google";
        }

        Usuario usuario = cuentaUsuarioService.crearUsuario(nuevaPersona, RolSistema.PASAJERO, nombreUsuarioUnico,
                cuentaUsuarioService.codificar("Taxi123*")); // Contraseña por defecto para cuentas Google

        // Crear perfil de pasajero
        cuentaUsuarioService.crearPasajero(usuario);

        // Si hay foto, podria guardarse en foto_url del usuario
        if (picture != null) {
            usuario.setFotoUrl(picture);
            usuarioRepository.save(usuario);
        }

        return generarTokens(usuario);
    }

}
