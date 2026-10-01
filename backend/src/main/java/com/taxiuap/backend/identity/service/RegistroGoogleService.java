package com.taxiuap.backend.identity.service;

import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.function.Supplier;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.CarnetRequest;
import com.taxiuap.backend.identity.dto.ReglasRegistro;
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
 * Una cuenta creada con Google recibe una contrasena legible generada por el sistema, que le llega
 * por correo al registrarse (CredencialesCorreoService). Si la persona ya tenia otra cuenta de la app,
 * la nueva reutiliza su nombre de usuario y su contrasena (regla 12: pasajero y conductor comparten
 * credenciales).
 *
 * Quien todavia no registro su carnet no queda guardado al elegir su cuenta de Google: recibe un
 * codigo temporal (IngresoGoogleTemporal) y la persona, el carnet y la cuenta se crean juntos, en una
 * sola transaccion, recien cuando confirma sus datos. Si cancela o algo falla no queda nada.
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
    private final CarnetService carnetService;
    private final LicenciaService licenciaService;

    /**
     * Boton "Continuar con Google" del login: entra con la cuenta que ya tenga (pasajero antes que
     * conductor; desde Mas cambia de modo). Sin cuentas de la app sigue como pasajero ([pasajero]).
     */
    public Optional<TokenResponse> ingresar(PerfilGoogle perfil, Supplier<byte[]> foto) {
        Optional<Persona> existente = personaActiva(perfil);
        if (existente.isPresent()) {
            Persona persona = existente.get();
            for (RolSistema rol : ROLES_APP) {
                Optional<Usuario> cuenta = cuentaActiva(persona, rol);
                if (cuenta.isPresent()) return Optional.of(autenticacionService.tokensDe(cuenta.get()));
            }
            if (!cuentasActivas(persona).isEmpty()) {
                throw new NegocioException("Esta cuenta es de administrador: ingresa con tu usuario y contraseña");
            }
        }
        return pasajero(perfil, foto);
    }

    /**
     * Pasajero con Google: si ya lo es, entra; si la persona ya registro su carnet (por ejemplo, es
     * conductor) se le crea la cuenta de pasajero. Si no, vacio: no se guarda nada hasta que confirme
     * su carnet ([registrarPasajeroConCarnet]).
     */
    public Optional<TokenResponse> pasajero(PerfilGoogle perfil, Supplier<byte[]> foto) {
        Optional<Persona> existente = personaActiva(perfil);
        if (existente.isPresent()) {
            Persona persona = existente.get();
            // Un pasajero de antes que no registro su carnet tambien entra: la app se lo pide.
            Optional<Usuario> cuenta = cuentaActiva(persona, RolSistema.PASAJERO);
            if (cuenta.isPresent()) return Optional.of(autenticacionService.tokensDe(cuenta.get()));
            if (!sinCarnet(persona)) return Optional.of(crearPasajero(persona, foto.get()));
        }
        return Optional.empty();
    }

    /**
     * Termina el registro de pasajero con Google: con las fotos y los datos del carnet que la persona
     * confirmo se crean (o completan) la persona, el carnet y la cuenta, todo junto. Las credenciales
     * salen por correo despues de confirmar la transaccion; si algo falla no queda nada guardado.
     */
    public TokenResponse registrarPasajeroConCarnet(PerfilGoogle perfil, CarnetRequest datos, MultipartFile anverso,
            MultipartFile reverso, Supplier<byte[]> foto) {
        CarnetService.FotosCarnet fotos = carnetService.validar(anverso, reverso);
        carnetService.verificarLectura(fotos, datos.ci(), datos.complementoCi(), datos.fechaNacimiento(),
                datos.nombres(), datos.apellidos());
        Optional<Persona> existente = personaActiva(perfil);
        if (existente.isPresent() && cuentaActiva(existente.get(), RolSistema.PASAJERO).isPresent()) {
            throw new ConflictoException("Ya tienes una cuenta de pasajero: ingresa con Google desde el inicio");
        }
        Persona persona;
        if (existente.isPresent()) {
            persona = existente.get();
            carnetService.actualizarDatos(persona, datos);
        } else {
            // El nombre es el del carnet; el de Google (puede ser un apodo) solo si no llego.
            persona = gestionPersonaService.registrarEntidad(new PersonaRequest(datos.ci().trim(),
                    vacioANull(datos.complementoCi()),
                    ReglasRegistro.nombreOActual(datos.nombres(), perfil.nombres()),
                    ReglasRegistro.nombreOActual(datos.apellidos(), perfil.apellidos()),
                    datos.fechaNacimiento(), perfil.correo(), null));
            persona.setIngresoGoogle(true);
        }
        carnetService.guardar(persona, fotos);
        return crearPasajero(persona, foto.get());
    }

    /** Cuenta de pasajero de una persona con su carnet ya registrado, y su correo de bienvenida. */
    private TokenResponse crearPasajero(Persona persona, byte[] foto) {
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
     * admin lo apruebe, con la moto y los PDF en revision, salvo que la app haya verificado su
     * licencia contra el carnet: entonces queda APROBADO.
     */
    public TokenResponse registrarConductor(PerfilGoogle perfil, RegistroConductorGoogleRequest datos,
            Map<String, MultipartFile> archivos) {
        Optional<Persona> existente = personaActiva(perfil);
        if (existente.isPresent() && cuentaActiva(existente.get(), RolSistema.CONDUCTOR).isPresent()) {
            throw new ConflictoException("Ya tienes una cuenta de conductor: ingresa con Google desde el inicio");
        }
        // Se valida todo antes de crear nada. Si la persona ya registro su carnet no se pide de nuevo.
        Map<TipoDocumento, MultipartFile> documentos = registroMotoConductorService.validar(datos.conductor(), archivos, false);
        List<byte[]> qrs = qrPagoConductorService.validarDelRegistro(archivos);
        CarnetService.FotosCarnet carnet = carnetService.validarDelRegistro(existente.orElse(null), archivos);
        LicenciaService.FotosLicencia licencia = licenciaService.validarDelRegistro(archivos);
        String ci = carnet == null ? existente.get().getCi() : datos.ci();
        String complemento = carnet == null ? existente.get().getComplementoCi() : datos.complementoCi();
        carnetService.verificarLectura(carnet, datos.ci(), datos.complementoCi(), datos.fechaNacimiento(),
                datos.nombres(), datos.apellidos());
        licenciaService.validarDatosRegistro(datos.conductor(), licencia, ci, complemento);

        Persona persona;
        if (existente.isPresent()) {
            persona = existente.get();
            completarDatos(persona, datos, carnet == null);
        } else {
            // El nombre es el del carnet; el de Google (puede ser un apodo) solo si no llego.
            persona = gestionPersonaService.registrarEntidad(new PersonaRequest(datos.ci(), datos.complementoCi(),
                    ReglasRegistro.nombreOActual(datos.nombres(), perfil.nombres()),
                    ReglasRegistro.nombreOActual(datos.apellidos(), perfil.apellidos()),
                    datos.fechaNacimiento(), perfil.correo(), datos.telefono()));
            persona.setIngresoGoogle(true);
        }
        if (carnet != null) {
            carnetService.guardar(persona, carnet);
        }

        CuentaNueva nueva = crearCuenta(persona, RolSistema.CONDUCTOR);
        Usuario usuario = nueva.usuario();
        Conductor conductor = cuentaUsuarioService.crearConductor(usuario, datos.conductor().numeroLicencia(),
                datos.conductor().categoriaLicencia());
        registroMotoConductorService.registrar(conductor, datos.conductor(), documentos);
        licenciaService.guardar(conductor, licencia, datos.conductor().vencimientoLicencia());
        qrPagoConductorService.guardarDelRegistro(conductor, qrs);
        boolean aprobado = licenciaService.aprobarSiVerificada(conductor, licencia);
        entregarCredencialesConductor(persona, usuario, nueva, aprobado);
        return autenticacionService.tokensDe(entradaDe(persona, usuario));
    }

    /**
     * Con el registro (y el carnet) guardado le llegan sus credenciales y el aviso de que su cuenta de
     * conductor esta en revision (o ya aprobada). Si reutilizo las de una cuenta de pasajero que nunca las recibio, se
     * generan unas nuevas para las dos cuentas.
     */
    private void entregarCredencialesConductor(Persona persona, Usuario usuario, CuentaNueva nueva, boolean aprobado) {
        String contrasena = nueva.contrasena();
        if (contrasena == null && Boolean.TRUE.equals(usuario.getContrasenaGenerada())) {
            contrasena = CredencialesCorreoService.contrasenaLegible();
        }
        if (contrasena != null) {
            credencialesCorreoService.aplicarEnCuentasDeApp(persona, contrasena, false);
        }
        credencialesCorreoService.conductorRegistrado(usuario, contrasena, "la misma de tu cuenta de pasajero", aprobado);
    }

    private static String vacioANull(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim().toUpperCase(Locale.ROOT);
    }

    private static boolean sinCarnet(Persona persona) {
        return persona.getCi() == null || persona.getCi().isBlank();
    }

    // ------------------------------------------------------------------ apoyo

    /**
     * Persona con el correo de Google. Queda marcada como que entro con Google: si no tiene CI, la
     * app le pide la foto de su carnet.
     */
    private Optional<Persona> personaActiva(PerfilGoogle perfil) {
        Optional<Persona> persona = personaRepository.findByCorreo(perfil.correo());
        if (persona.isPresent() && persona.get().getEstadoPersona() != EstadoRegistro.A) {
            throw new NegocioException("La cuenta de " + perfil.correo() + " no esta activa");
        }
        persona.ifPresent(p -> p.setIngresoGoogle(true));
        return persona;
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
    /** Con el carnet ya registrado ([conservarCarnet]) el CI, el complemento y la fecha no cambian. */
    private void completarDatos(Persona persona, RegistroConductorGoogleRequest datos, boolean conservarCarnet) {
        gestionPersonaService.actualizar(persona.getId(), new PersonaRequest(
                conservarCarnet ? persona.getCi() : datos.ci(),
                conservarCarnet ? persona.getComplementoCi() : datos.complementoCi(),
                conservarCarnet ? persona.getNombres() : ReglasRegistro.nombreOActual(datos.nombres(), persona.getNombres()),
                conservarCarnet ? persona.getApellidos() : ReglasRegistro.nombreOActual(datos.apellidos(), persona.getApellidos()),
                conservarCarnet ? persona.getFechaNacimiento() : datos.fechaNacimiento(),
                persona.getCorreo(),
                datos.telefono()));
    }

    /** Nombre y correo de Google mas lo que ya se sabia de la persona, para el formulario de conductor. */
    @Transactional(readOnly = true)
    public PerfilGoogleResponse perfilParaRegistro(PerfilGoogle perfil) {
        Optional<Persona> persona = personaRepository.findByCorreo(perfil.correo())
                .filter(p -> p.getEstadoPersona() == EstadoRegistro.A);
        // Si ya estaba registrada se usa su nombre (con el que se compara la licencia).
        return new PerfilGoogleResponse(perfil.correo(),
                persona.map(Persona::getNombres).orElse(perfil.nombres()),
                persona.map(Persona::getApellidos).orElse(perfil.apellidos()),
                persona.map(Persona::getCi).orElse(null),
                persona.map(Persona::getComplementoCi).orElse(null),
                persona.map(Persona::getTelefono).orElse(null),
                persona.map(Persona::getFechaNacimiento).orElse(null),
                persona.map(carnetService::tieneCarnet).orElse(false));
    }
}
