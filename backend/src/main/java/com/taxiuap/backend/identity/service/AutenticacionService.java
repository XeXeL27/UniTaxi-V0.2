package com.taxiuap.backend.identity.service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.JwtService;
import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.config.security.TipoToken;
import com.taxiuap.backend.identity.dto.CambiarContrasenaRequest;
import com.taxiuap.backend.identity.dto.LoginRequest;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.dto.RefreshRequest;
import com.taxiuap.backend.identity.dto.RegistroConductorRequest;
import com.taxiuap.backend.identity.dto.RegistroPasajeroRequest;
import com.taxiuap.backend.identity.dto.TokenResponse;
import com.taxiuap.backend.identity.dto.UsuarioResponse;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.pricing.service.QrPagoConductorService;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.CredencialesInvalidasException;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.vehicle.enums.TipoDocumento;
import com.taxiuap.backend.vehicle.service.RegistroMotoConductorService;

import io.jsonwebtoken.JwtException;
import lombok.RequiredArgsConstructor;

import static com.taxiuap.backend.identity.service.CuentaUsuarioService.normalizarNombreUsuario;

/** Registro publico (desde la app), inicio de sesion y renovacion de tokens. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AutenticacionService {

    private static final String MENSAJE_CREDENCIALES_INVALIDAS = "Credenciales invalidas";
    public static final String MENSAJE_CUENTA_SUSPENDIDA =
            "Tu cuenta esta suspendida. Comunicate con la administracion de TaxiUAP";

    private final PersonaRepository personaRepository;
    private final UsuarioRepository usuarioRepository;
    private final ConductorRepository conductorRepository;
    private final GestionPersonaService gestionPersonaService;
    private final CuentaUsuarioService cuentaUsuarioService;
    private final PasswordEncoder passwordEncoder;
    private final RegistroMotoConductorService registroMotoConductorService;
    private final QrPagoConductorService qrPagoConductorService;
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

    /**
     * Registro publico de conductor con el formulario: persona, cuenta, conductor PENDIENTE, su moto
     * y los PDF (CI y LICENCIA obligatorios) en revision. Los PDF se validan antes de crear nada.
     */
    @Transactional
    public TokenResponse registrarConductor(RegistroConductorRequest datos, Map<String, MultipartFile> archivos) {
        Map<TipoDocumento, MultipartFile> documentos = registroMotoConductorService.validar(datos.conductor(), archivos, false);
        List<byte[]> qrs = qrPagoConductorService.validarDelRegistro(archivos);
        String nombreUsuario = normalizarNombreUsuario(datos.nombreUsuario());
        cuentaUsuarioService.validarNombreUsuarioDisponible(nombreUsuario, null);

        Persona persona = gestionPersonaService.registrarEntidad(new PersonaRequest(datos.ci(), datos.complementoCi(),
                datos.nombres(), datos.apellidos(), datos.fechaNacimiento(), datos.correo(), datos.telefono()));
        Usuario usuario = cuentaUsuarioService.crearUsuario(persona, RolSistema.CONDUCTOR, nombreUsuario,
                cuentaUsuarioService.codificar(datos.password()));
        Conductor conductor = cuentaUsuarioService.crearConductor(usuario, datos.conductor().numeroLicencia(),
                datos.conductor().categoriaLicencia());
        registroMotoConductorService.registrar(conductor, datos.conductor(), documentos);
        qrPagoConductorService.guardarDelRegistro(conductor, qrs);

        return generarTokens(usuario);
    }

    /** Tokens de una cuenta ya autenticada por otro medio (Google). */
    public TokenResponse tokensDe(Usuario usuario) {
        return generarTokens(usuario);
    }

    /**
     * El identificador puede ser nombre de usuario, correo o telefono. Si con esas credenciales hay
     * mas de una cuenta (la misma persona como pasajero y conductor) hace falta indicar el rol.
     */
    public TokenResponse login(LoginRequest datos) {
        List<Usuario> candidatos = sinSuspendidas(buscarCandidatos(datos.usuario().trim()).stream()
                .filter(u -> u.getEstadoUsuario() != EstadoRegistro.X)
                .filter(u -> u.getPersona().getEstadoPersona() == EstadoRegistro.A)
                .filter(u -> datos.rol() == null || datos.rol().isBlank()
                        || u.getRol().getCodigo().equalsIgnoreCase(datos.rol().trim()))
                .filter(u -> passwordEncoder.matches(datos.password(), u.getPasswordHash()))
                .toList());

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
        List<Usuario> usuarios = sinSuspendidas(buscarCandidatos(identificador.trim()).stream()
                .filter(u -> u.getEstadoUsuario() != EstadoRegistro.X)
                .filter(u -> u.getPersona().getEstadoPersona() == EstadoRegistro.A)
                .filter(u -> passwordEncoder.matches(password, u.getPasswordHash()))
                .toList());
        if (usuarios.isEmpty()) {
            throw new CredencialesInvalidasException(MENSAJE_CREDENCIALES_INVALIDAS);
        }
        // Con cuenta de pasajero, la de conductor solo cuenta cuando el admin ya la aprobo: mientras
        // tanto entra directo como pasajero, sin preguntarle.
        boolean tienePasajero = usuarios.stream().anyMatch(u -> esRol(u, RolSistema.PASAJERO));
        return usuarios.stream()
                .filter(u -> !tienePasajero || conductorHabilitado(u))
                .map(u -> u.getRol().getCodigo())
                .distinct()
                .toList();
    }

    /**
     * Deja solo las cuentas activas. Si la contrasena era correcta pero todas las cuentas estan
     * suspendidas, se avisa eso en vez de "credenciales invalidas".
     */
    private static List<Usuario> sinSuspendidas(List<Usuario> cuentas) {
        List<Usuario> activas = cuentas.stream().filter(u -> u.getEstadoUsuario() == EstadoRegistro.A).toList();
        if (activas.isEmpty() && !cuentas.isEmpty()) {
            throw new NegocioException(MENSAJE_CUENTA_SUSPENDIDA);
        }
        return activas;
    }

    /** true si no es cuenta de conductor, o si lo es y el administrador ya la aprobo. */
    public boolean conductorHabilitado(Usuario usuario) {
        if (!esRol(usuario, RolSistema.CONDUCTOR)) return true;
        return conductorRepository.findByUsuarioId(usuario.getId())
                .map(c -> c.getSituacionAprobacion() == SituacionAprobacion.APROBADO)
                .orElse(false);
    }

    private static boolean esRol(Usuario usuario, RolSistema rol) {
        return rol.getCodigo().equals(usuario.getRol().getCodigo());
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
        Usuario cuenta = usuarioRepository.findByPersonaId(actual.getPersona().getId()).stream()
                .filter(u -> u.getEstadoUsuario() == EstadoRegistro.A)
                .filter(u -> u.getRol().getCodigo().equals(destino))
                .findFirst()
                .orElseThrow(() -> new NegocioException("No tiene una cuenta de " + destino.toLowerCase()));
        if (!conductorHabilitado(cuenta)) {
            throw new NegocioException("Tu registro de conductor todavia esta en revision");
        }
        return generarTokens(cuenta);
    }

    /**
     * Cambia la contrasena de quien tiene la sesion iniciada. Las cuentas de pasajero y conductor de
     * una persona comparten credenciales (regla 12), asi que se cambian juntas; la de administrador
     * se cambia sola.
     */
    @Transactional
    public void cambiarContrasena(Long idUsuarioActual, CambiarContrasenaRequest datos) {
        Usuario actual = usuarioRepository.findById(idUsuarioActual)
                .orElseThrow(() -> new CredencialesInvalidasException(MENSAJE_CREDENCIALES_INVALIDAS));
        if (!passwordEncoder.matches(datos.actual(), actual.getPasswordHash())) {
            throw new NegocioException("La contrasena actual no es correcta");
        }
        if (!datos.nueva().equals(datos.confirmacion())) {
            throw new NegocioException("La confirmacion no coincide con la nueva contrasena");
        }
        if (datos.nueva().equals(datos.actual())) {
            throw new NegocioException("La nueva contrasena debe ser distinta de la actual");
        }

        String hash = cuentaUsuarioService.codificar(datos.nueva());
        List<Usuario> cuentas = esCuentaDeApp(actual)
                ? usuarioRepository.findByPersonaId(actual.getPersona().getId()).stream()
                        .filter(u -> u.getEstadoUsuario() == EstadoRegistro.A)
                        .filter(this::esCuentaDeApp)
                        .toList()
                : List.of(actual);
        cuentas.forEach(u -> {
            u.setPasswordHash(hash);
            u.setContrasenaGenerada(false);
        });
        usuarioRepository.saveAll(cuentas);
    }

    private boolean esCuentaDeApp(Usuario usuario) {
        String codigo = usuario.getRol().getCodigo();
        return RolSistema.PASAJERO.getCodigo().equals(codigo) || RolSistema.CONDUCTOR.getCodigo().equals(codigo);
    }

    public TokenResponse refrescar(RefreshRequest datos) {
        try {
            var jwtUser = jwtService.validar(datos.tokenRefresco(), TipoToken.REFRESCO);
            Usuario usuario = usuarioRepository.findById(jwtUser.idUsuario())
                    .orElseThrow(() -> new CredencialesInvalidasException(MENSAJE_CREDENCIALES_INVALIDAS));

            if (usuario.getEstadoUsuario() == EstadoRegistro.S) {
                throw new NegocioException(MENSAJE_CUENTA_SUSPENDIDA);
            }
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

        // La cuenta de conductor sin aprobar no se ofrece como "cambiar a modo conductor".
        List<String> rolesDisponibles = usuarioRepository.findByPersonaId(persona.getId()).stream()
                .filter(u -> u.getEstadoUsuario() == EstadoRegistro.A)
                .filter(u -> u.getId().equals(usuario.getId()) || conductorHabilitado(u))
                .map(u -> u.getRol().getCodigo())
                .distinct()
                .toList();

        return new TokenResponse(tokenAcceso, tokenRefresco, jwtService.getExpiracionMs(), usuarioResponse,
                rolesDisponibles);
    }
}
