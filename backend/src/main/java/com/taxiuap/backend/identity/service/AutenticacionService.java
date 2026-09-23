package com.taxiuap.backend.identity.service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

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
        String nombreUsuario = CuentaUsuarioService.normalizarNombreUsuario(datos.nombreUsuario());
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
        String nombreUsuario = CuentaUsuarioService.normalizarNombreUsuario(datos.nombreUsuario());
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
        usuarioRepository.findByNombreUsuario(CuentaUsuarioService.normalizarNombreUsuario(identificador))
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

        return new TokenResponse(tokenAcceso, tokenRefresco, jwtService.getExpiracionMs(), usuarioResponse);
    }
}
