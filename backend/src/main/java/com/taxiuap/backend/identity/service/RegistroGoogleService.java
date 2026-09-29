package com.taxiuap.backend.identity.service;

import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.PerfilGoogle;
import com.taxiuap.backend.identity.dto.PerfilGoogleResponse;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.dto.RegistroConductorGoogleRequest;
import com.taxiuap.backend.identity.dto.TokenResponse;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.pricing.service.QrPagoConductorService;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.ConflictoException;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.vehicle.enums.TipoDocumento;
import com.taxiuap.backend.vehicle.service.RegistroMotoConductorService;

import lombok.RequiredArgsConstructor;

/**
 * Ingreso y registro con Google. La persona se reconoce por su correo.
 *
 * Una cuenta creada con Google recibe una contrasena legible generada por el sistema: el pasajero
 * la recibe por correo al registrarse y el conductor recien cuando el admin lo aprueba
 * (CredencialesCorreoService). Si la persona ya tenia otra cuenta de la app, la nueva reutiliza su
 * nombre de usuario y su contrasena (regla 12: pasajero y conductor comparten credenciales).
 */
@Service
@RequiredArgsConstructor
@Transactional
public class RegistroGoogleService {

    private static final List<RolSistema> ROLES_APP = List.of(RolSistema.PASAJERO, RolSistema.CONDUCTOR);

    private final PersonaRepository personaRepository;
    private final UsuarioRepository usuarioRepository;
    private final GestionPersonaService gestionPersonaService;
    private final CuentaUsuarioService cuentaUsuarioService;
    private final RegistroMotoConductorService registroMotoConductorService;
    private final QrPagoConductorService qrPagoConductorService;
    private final FotoPerfilService fotoPerfilService;
    private final AutenticacionService autenticacionService;
    private final CredencialesCorreoService credencialesCorreoService;

    /**
     * Boton "Continuar con Google" del login: entra con la cuenta que ya tenga (pasajero antes que
     * conductor; desde Mas cambia de modo). Sin cuentas de la app se registra como pasajero.
     */
    public TokenResponse ingresar(PerfilGoogle perfil, byte[] foto) {
        Optional<Persona> existente = personaActiva(perfil);
        if (existente.isPresent()) {
            Persona persona = existente.get();
            for (RolSistema rol : ROLES_APP) {
                Optional<Usuario> cuenta = cuentaActiva(persona, rol);
                if (cuenta.isPresent()) return autenticacionService.tokensDe(cuenta.get());
            }
            if (!cuentasActivas(persona).isEmpty()) {
                throw new NegocioException("Esta cuenta es de administrador: ingresa con tu usuario y contraseña");
            }
        }
        return registrarPasajero(perfil, foto);
    }

    /** Registro de pasajero: si ya lo es, simplemente entra. */
    public TokenResponse registrarPasajero(PerfilGoogle perfil, byte[] foto) {
        Persona persona = personaActiva(perfil).orElseGet(() -> nuevaPersona(perfil));
        Optional<Usuario> cuenta = cuentaActiva(persona, RolSistema.PASAJERO);
        if (cuenta.isPresent()) return autenticacionService.tokensDe(cuenta.get());

        CuentaNueva nueva = crearCuenta(persona, RolSistema.PASAJERO);
        Usuario usuario = nueva.usuario();
        cuentaUsuarioService.crearPasajero(usuario);
        if (foto != null) fotoPerfilService.guardarImagen(usuario, foto);
        enviarBienvenida(persona, nueva);
        return autenticacionService.tokensDe(usuario);
    }

    /**
     * Correo con las credenciales del pasajero. Si reutilizo las de un conductor de Google que
     * nadie conoce (todavia sin aprobar), se generan unas nuevas para las dos cuentas.
     */
    private void enviarBienvenida(Persona persona, CuentaNueva nueva) {
        Usuario usuario = nueva.usuario();
        String contrasena = nueva.contrasena();
        if (contrasena == null && Boolean.TRUE.equals(usuario.getContrasenaGenerada())) {
            contrasena = CredencialesCorreoService.contrasenaLegible();
        }
        if (contrasena != null) {
            credencialesCorreoService.aplicarEnCuentasDeApp(persona, contrasena, false);
        }
        credencialesCorreoService.bienvenidaPasajero(usuario, contrasena, "la misma de tu cuenta de conductor");
    }

    /**
     * Si ya es conductor entra directo; si no, hace falta el formulario (licencia, moto, PDF). Si su
     * cuenta de conductor todavia no esta aprobada y tambien es pasajero, entra como pasajero.
     */
    @Transactional(readOnly = true)
    public Optional<TokenResponse> conductorExistente(PerfilGoogle perfil) {
        return personaActiva(perfil).flatMap(persona -> cuentaActiva(persona, RolSistema.CONDUCTOR)
                .map(conductor -> autenticacionService.tokensDe(entradaDe(persona, conductor))));
    }

    /** Cuenta con que entra quien acaba de ser (o ya era) conductor: pasajero mientras no lo aprueben. */
    private Usuario entradaDe(Persona persona, Usuario conductor) {
        if (autenticacionService.conductorHabilitado(conductor)) return conductor;
        return cuentaActiva(persona, RolSistema.PASAJERO).orElse(conductor);
    }

    /**
     * Registro de conductor con los datos de Google y el formulario. Queda PENDIENTE hasta que el
     * admin lo apruebe, con la moto y los PDF en revision.
     */
    public TokenResponse registrarConductor(PerfilGoogle perfil, RegistroConductorGoogleRequest datos,
            Map<String, MultipartFile> archivos) {
        Map<TipoDocumento, MultipartFile> documentos = registroMotoConductorService.validar(datos.conductor(), archivos);
        List<byte[]> qrs = qrPagoConductorService.validarDelRegistro(archivos);

        Optional<Persona> existente = personaActiva(perfil);
        Persona persona;
        if (existente.isPresent()) {
            persona = existente.get();
            if (cuentaActiva(persona, RolSistema.CONDUCTOR).isPresent()) {
                throw new ConflictoException("Ya tienes una cuenta de conductor: ingresa con Google desde el inicio");
            }
            completarDatos(persona, datos);
        } else {
            persona = gestionPersonaService.registrarEntidad(new PersonaRequest(datos.ci(), datos.complementoCi(),
                    perfil.nombres(), perfil.apellidos(), datos.fechaNacimiento(), perfil.correo(), datos.telefono()));
        }

        CuentaNueva nueva = crearCuenta(persona, RolSistema.CONDUCTOR);
        Usuario usuario = nueva.usuario();
        // La contrasena nueva no se entrega ahora: llega por correo cuando el admin lo aprueba.
        if (nueva.contrasena() != null) usuario.setContrasenaGenerada(true);
        Conductor conductor = cuentaUsuarioService.crearConductor(usuario, datos.conductor().numeroLicencia(),
                datos.conductor().categoriaLicencia());
        registroMotoConductorService.registrar(conductor, datos.conductor(), documentos);
        qrPagoConductorService.guardarDelRegistro(conductor, qrs);
        return autenticacionService.tokensDe(entradaDe(persona, usuario));
    }

    // ------------------------------------------------------------------ apoyo

    private Optional<Persona> personaActiva(PerfilGoogle perfil) {
        Optional<Persona> persona = personaRepository.findByCorreo(perfil.correo());
        if (persona.isPresent() && persona.get().getEstadoPersona() != EstadoRegistro.A) {
            throw new NegocioException("La cuenta de " + perfil.correo() + " no esta activa");
        }
        return persona;
    }

    private Persona nuevaPersona(PerfilGoogle perfil) {
        // Google no da CI ni telefono: quedan null (se completan al registrarse como conductor).
        return gestionPersonaService.registrarEntidad(new PersonaRequest(null, null, perfil.nombres(),
                perfil.apellidos(), null, perfil.correo(), null));
    }

    private List<Usuario> cuentasActivas(Persona persona) {
        return usuarioRepository.findByPersonaId(persona.getId()).stream()
                .filter(u -> u.getEstadoUsuario() == EstadoRegistro.A)
                .toList();
    }

    /** Cuenta activa de ese rol. Si esta suspendida no se entra ni se crea otra: se avisa. */
    private Optional<Usuario> cuentaActiva(Persona persona, RolSistema rol) {
        boolean suspendida = usuarioRepository.findByPersonaId(persona.getId()).stream()
                .anyMatch(u -> u.getEstadoUsuario() == EstadoRegistro.S && rol.getCodigo().equals(u.getRol().getCodigo()));
        if (suspendida) {
            throw new NegocioException(AutenticacionService.MENSAJE_CUENTA_SUSPENDIDA);
        }
        return cuentasActivas(persona).stream().filter(u -> rol.getCodigo().equals(u.getRol().getCodigo())).findFirst();
    }

    /** Cuenta recien creada; contrasena solo si el sistema la acaba de generar (si no, null). */
    private record CuentaNueva(Usuario usuario, String contrasena) {
    }

    /** Reutiliza las credenciales de la otra cuenta de la app; si no hay, genera unas nuevas. */
    private CuentaNueva crearCuenta(Persona persona, RolSistema rol) {
        Optional<Usuario> otra = cuentasActivas(persona).stream()
                .filter(u -> ROLES_APP.stream().anyMatch(r -> r.getCodigo().equals(u.getRol().getCodigo())))
                .findFirst();
        if (otra.isPresent()) {
            Usuario usuario = cuentaUsuarioService.crearUsuario(persona, rol, otra.get().getNombreUsuario(),
                    otra.get().getPasswordHash());
            usuario.setContrasenaGenerada(otra.get().getContrasenaGenerada());
            return new CuentaNueva(usuario, null);
        }
        String contrasena = CredencialesCorreoService.contrasenaLegible();
        Usuario usuario = cuentaUsuarioService.crearUsuario(persona, rol, nombreUsuarioLibre(persona.getCorreo()),
                cuentaUsuarioService.codificar(contrasena));
        return new CuentaNueva(usuario, contrasena);
    }

    /**
     * Nombre de usuario a partir del correo (lo de antes de la @, con las reglas de NombreUsuario);
     * si ya existe se le agrega un numero.
     */
    private String nombreUsuarioLibre(String correo) {
        String base = correo.split("@")[0].toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9._-]", ".");
        if (base.length() < 3) base = base + "usuario";
        if (base.length() > 40) base = base.substring(0, 40);
        String candidato = base;
        for (int i = 2; !usuarioRepository.findByNombreUsuario(candidato).isEmpty(); i++) {
            candidato = base + i;
        }
        return candidato;
    }

    /** La persona ya existia (por ejemplo, pasajero de Google sin CI): se completa lo que falte. */
    /**
     * Completa a la persona (por ejemplo, un pasajero que entro solo con Google) con lo que pide el
     * registro de conductor. El formulario llega precargado con lo que ya se sabia, asi que manda lo
     * que la persona confirmo.
     */
    private void completarDatos(Persona persona, RegistroConductorGoogleRequest datos) {
        gestionPersonaService.actualizar(persona.getId(), new PersonaRequest(
                datos.ci(),
                datos.complementoCi(),
                persona.getNombres(),
                persona.getApellidos(),
                datos.fechaNacimiento(),
                persona.getCorreo(),
                datos.telefono()));
    }

    /** Nombre y correo de Google mas lo que ya se sabia de la persona, para el formulario de conductor. */
    @Transactional(readOnly = true)
    public PerfilGoogleResponse perfilParaRegistro(PerfilGoogle perfil) {
        Optional<Persona> persona = personaRepository.findByCorreo(perfil.correo())
                .filter(p -> p.getEstadoPersona() == EstadoRegistro.A);
        return new PerfilGoogleResponse(perfil.correo(), perfil.nombres(), perfil.apellidos(),
                persona.map(Persona::getCi).orElse(null),
                persona.map(Persona::getComplementoCi).orElse(null),
                persona.map(Persona::getTelefono).orElse(null),
                persona.map(Persona::getFechaNacimiento).orElse(null));
    }
}
