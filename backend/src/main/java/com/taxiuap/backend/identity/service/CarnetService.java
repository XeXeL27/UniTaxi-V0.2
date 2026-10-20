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
import com.taxiuap.backend.identity.dto.LecturaDocumentoResponse;
import com.taxiuap.backend.identity.dto.LecturaSelfieResponse;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.dto.UsuarioResponse;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.DocumentoIdentidad;
import com.taxiuap.backend.identity.enums.LadoDocumento;
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
import lombok.extern.slf4j.Slf4j;

/**
 * Carnet de identidad de quien entra con Google: fotos del anverso y del reverso (en la carpeta
 * general/carnet de la persona) y los datos que la app leyo de ellas (CI, complemento y fecha de
 * nacimiento). La app solo acepta fotos en las que reconoce un carnet boliviano.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional
public class CarnetService {

    public static final String PARTE_ANVERSO = "CARNET_ANVERSO";
    public static final String PARTE_REVERSO = "CARNET_REVERSO";
    public static final String PARTE_SELFIE = "CARNET_SELFIE";

    /** Motivo de un carnet OBSERVADO a pedido de la persona. */
    public static final String MOTIVO_PEDIDO = "La persona indicó que el sistema leyó mal sus datos";

    /** Motivo de un carnet OBSERVADO porque el servidor no pudo revisar la foto con el carnet. */
    public static final String MOTIVO_SELFIE_SIN_REVISAR =
            "No se pudo revisar automáticamente la foto con el carnet (lector no disponible)";

    /**
     * Comienzo del motivo cuando la observacion sale de una cuenta que ya usaba la app (subio su foto con
     * el carnet o renovo su carnet): al aprobarla no se reenvian credenciales.
     */
    public static final String PREFIJO_CUENTA_EXISTENTE = "Cuenta existente: ";

    /** Las rutas del anverso o del reverso estan anotadas pero los archivos ya no estan en el servidor. */
    public static final String MENSAJE_FALTAN_FOTOS =
            "No encontramos las fotos de tu carnet: tómalas de nuevo (anverso y reverso) junto con tu foto con el carnet";

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
        return PARTE_ANVERSO.equals(parte) || PARTE_REVERSO.equals(parte) || PARTE_SELFIE.equals(parte);
    }

    /**
     * Fotos del carnet ya procesadas (JPEG), listas para guardar, y la huella de las fotos tal como
     * llegaron (para buscar lo que Gemini leyo de ellas).
     */
    public record FotosCarnet(byte[] anverso, byte[] reverso, byte[] selfie, String huellaAnverso,
            String huellaReverso, String huellaSelfie) {
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
            verificarSelfie(fotos, ci);
        }
    }

    /** El carnet que sostiene en la foto con el carnet debe ser el mismo (si el servidor la reviso). */
    private void verificarSelfie(FotosCarnet fotos, String ci) {
        LecturaSelfieResponse selfie = lecturaDocumentoService.selfie(fotos.huellaSelfie(), fotos.huellaAnverso());
        if (selfie != null && selfie.numero() != null && (ci == null || !selfie.numero().equals(ci.trim()))) {
            throw new NegocioException("El carnet de tu foto con el carnet no es el mismo de las fotos de tu carnet. "
                    + "Vuelve a tomar la foto.");
        }
    }

    /**
     * Por que la foto con el carnet deja la cuenta OBSERVADA: el servidor no la pudo revisar, la cara no
     * se parece a la del carnet o parece foto de una pantalla. null si esta bien.
     */
    private String observacionSelfie(FotosCarnet fotos) {
        LecturaSelfieResponse selfie = lecturaDocumentoService.selfie(fotos.huellaSelfie(), fotos.huellaAnverso());
        return selfie == null ? MOTIVO_SELFIE_SIN_REVISAR : selfie.observacion();
    }

    private void verificarLectura(FotosCarnet fotos, CarnetRequest datos) {
        verificarLectura(fotos, datos.ci(), datos.complementoCi(), datos.fechaNacimiento(), datos.nombres(),
                datos.apellidos());
    }

    /**
     * Con el carnet ya guardado: queda OBSERVADO si la persona pidio la revision ([pedido]), si su
     * nombre no parece real (NombresPermitidos) o si la foto con el carnet no paso la revision del
     * servidor (sin revisar, otra cara o foto de una pantalla); si no, VERIFICADO. Mientras este observado no usa la
     * app ni recibe sus credenciales: las recibe cuando un administrador lo aprueba
     * (RevisionCarnetService). Devuelve true si quedo observado.
     *
     * Antes de enviar el carnet la persona debe aceptar los terminos y condiciones ([aceptaTerminos]);
     * queda la fecha en persona.fecha_acepta_terminos.
     */
    public boolean revisar(Persona persona, FotosCarnet fotos, boolean pedido, boolean aceptaTerminos) {
        if (!aceptaTerminos) {
            throw new NegocioException("Debes aceptar los términos y condiciones para continuar");
        }
        persona.setFechaAceptaTerminos(LocalDateTime.now());
        String motivo = pedido ? MOTIVO_PEDIDO : NombresPermitidos.problema(persona.getNombres(), persona.getApellidos());
        if (motivo == null && fotos != null) {
            motivo = observacionSelfie(fotos);
        }
        return observarSi(persona, motivo);
    }

    /** OBSERVADO con [motivo] o, si es null, VERIFICADO. Devuelve true si quedo observado. */
    private static boolean observarSi(Persona persona, String motivo) {
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
    public UsuarioResponse registrar(Long idUsuario, CarnetRequest datos, MultipartFile anverso, MultipartFile reverso,
            MultipartFile selfie) {
        FotosCarnet fotos = validar(anverso, reverso, selfie);
        // Si la persona dice que sus datos se leyeron mal no se comparan con la lectura: los revisa el admin.
        if (!datos.esObservado()) verificarLectura(fotos, datos);
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new CredencialesInvalidasException("Credenciales invalidas"));
        Persona persona = usuario.getPersona();
        actualizarDatos(persona, datos);
        guardar(persona, fotos);
        if (!revisar(persona, fotos, datos.esObservado(), datos.aceptoTerminos())) entregarCredenciales(usuario);
        return respuesta(usuario);
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
        return validar(archivos.get(PARTE_ANVERSO), archivos.get(PARTE_REVERSO), archivos.get(PARTE_SELFIE));
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
        return persona.getCi() != null && !persona.getCi().isBlank() && fotosCarnetGuardadas(persona);
    }

    /**
     * Los archivos del anverso y del reverso estan en la carpeta de archivos. Si sus rutas estan anotadas
     * pero falta alguno (se movio la carpeta o el servidor no la ve) queda en el log; las rutas no se borran.
     */
    public boolean fotosCarnetGuardadas(Persona persona) {
        boolean anverso = almacenamientoArchivos.existe(persona.getCarnetAnversoUrl());
        boolean reverso = almacenamientoArchivos.existe(persona.getCarnetReversoUrl());
        if ((!anverso && persona.getCarnetAnversoUrl() != null) || (!reverso && persona.getCarnetReversoUrl() != null)) {
            log.warn("Faltan archivos del carnet de la persona {}: anverso {} ({}), reverso {} ({})", persona.getId(),
                    persona.getCarnetAnversoUrl(), anverso ? "esta" : "no esta",
                    persona.getCarnetReversoUrl(), reverso ? "esta" : "no esta");
        }
        return anverso && reverso;
    }

    /**
     * Datos de la cuenta para la app. Lo que le falta del carnet (carnetPendiente) se decide con los
     * archivos que de verdad estan en el servidor: si faltan, la app vuelve a pedir el anverso y el reverso.
     */
    public UsuarioResponse respuesta(Usuario usuario) {
        return UsuarioResponse.de(usuario, fotosCarnetGuardadas(usuario.getPersona()));
    }

    /**
     * El conductor vuelve a tomar las fotos de su carnet con un permiso del administrador (CARNET) y
     * confirmando con su contrasena. Se actualizan el CI, el complemento y la fecha leidos de ellas.
     */
    public UsuarioResponse reemplazarPorConductor(Long idUsuario, CarnetRequest datos, MultipartFile anverso,
            MultipartFile reverso, MultipartFile selfie) {
        FotosCarnet fotos = validar(anverso, reverso, selfie);
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
        String motivo = observacionSelfie(fotos);
        if (motivo != null) {
            observarSi(persona, PREFIJO_CUENTA_EXISTENTE + motivo);
        }
        return respuesta(usuario);
    }

    /** El administrador cambia una o varias fotos del carnet (y la foto con el carnet) de la persona de una cuenta. */
    public void reemplazarPorAdmin(Long idUsuario, MultipartFile anverso, MultipartFile reverso, MultipartFile selfie) {
        boolean conAnverso = anverso != null && !anverso.isEmpty();
        boolean conReverso = reverso != null && !reverso.isEmpty();
        boolean conSelfie = selfie != null && !selfie.isEmpty();
        if (!conAnverso && !conReverso && !conSelfie) {
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
        if (conSelfie) {
            guardarSelfie(persona, procesarSelfie(selfie));
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

    public FotosCarnet validar(MultipartFile anverso, MultipartFile reverso, MultipartFile selfie) {
        if (selfie == null || selfie.isEmpty()) {
            throw new NegocioException("Falta tu foto con el carnet. Si no la ves en la app, actualiza UNITAXI.");
        }
        return new FotosCarnet(procesar(anverso, "anverso"), procesar(reverso, "reverso"), procesarSelfie(selfie),
                LecturaDocumentoService.huella(anverso), LecturaDocumentoService.huella(reverso),
                LecturaDocumentoService.huella(selfie));
    }

    private static byte[] procesarSelfie(MultipartFile selfie) {
        if (selfie.getSize() > AlmacenamientoArchivos.TAMANO_MAXIMO_IMAGEN * 2) {
            throw new NegocioException("La foto con tu carnet supera los 10 MB");
        }
        try {
            return ProcesadorImagen.imagenCarnet(selfie.getBytes());
        } catch (IOException | IllegalArgumentException | IllegalStateException e) {
            throw new NegocioException("No se pudo leer la foto con tu carnet");
        }
    }

    /** Guarda las fotos en personas/<id>_<ci>/general/carnet y deja sus rutas en la persona. */
    public void guardar(Persona persona, FotosCarnet fotos) {
        LocalDate vence = lecturaDocumentoService.vencimientoCarnet(fotos.huellaAnverso());
        if (vence != null && vence.isBefore(LocalDate.now())) {
            throw new NegocioException("Tu carnet está vencido. Renuévalo en el SEGIP para continuar.");
        }
        String carpeta = almacenamientoArchivos.carpetaCarnet(persona);
        persona.setCarnetAnversoUrl(almacenamientoArchivos.reemplazarConSello(persona.getCarnetAnversoUrl(),
                fotos.anverso(), carpeta, "carnet_anverso", "jpg"));
        persona.setCarnetReversoUrl(almacenamientoArchivos.reemplazarConSello(persona.getCarnetReversoUrl(),
                fotos.reverso(), carpeta, "carnet_reverso", "jpg"));
        guardarSelfie(persona, fotos.selfie());
        // Sin lectura del servidor el vencimiento lo pone el administrador al revisar (queda OBSERVADO).
        persona.setCarnetVencimiento(vence);
    }

    private void guardarSelfie(Persona persona, byte[] selfie) {
        persona.setCarnetSelfieUrl(almacenamientoArchivos.reemplazarConSello(persona.getCarnetSelfieUrl(),
                selfie, almacenamientoArchivos.carpetaCarnet(persona), "carnet_selfie", "jpg"));
        persona.setPlazoSelfieCarnet(null);
    }

    /**
     * Cuenta que ya usaba la app: sube su foto con el carnet (cuentas de antes) o, si su carnet vencio o
     * no tiene sus fotos, el anverso, el reverso y la foto con el carnet. Los datos leidos deben ser los
     * que ya tiene registrados (no se cambian aqui). Si el servidor no pudo revisar la foto con el carnet,
     * la cara no se parece o no se sabe hasta cuando vale el carnet, queda OBSERVADA para el administrador.
     */
    public UsuarioResponse actualizarCuenta(Long idUsuario, MultipartFile anverso, MultipartFile reverso,
            MultipartFile selfie) {
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new CredencialesInvalidasException("Credenciales invalidas"));
        Persona persona = usuario.getPersona();
        if (persona.getCi() == null || persona.getCi().isBlank()) {
            throw new NegocioException("Primero registra tu carnet");
        }
        boolean conFotosCarnet = anverso != null && !anverso.isEmpty() && reverso != null && !reverso.isEmpty();
        if (!conFotosCarnet && (!tieneCarnet(persona) || carnetVencido(persona))) {
            throw new NegocioException(carnetVencido(persona)
                    ? "Tu carnet venció: toma las fotos de tu carnet nuevo y tu foto con el carnet"
                    : MENSAJE_FALTAN_FOTOS);
        }
        String motivo;
        if (conFotosCarnet) {
            FotosCarnet fotos = validar(anverso, reverso, selfie);
            lecturaDocumentoService.verificarCarnet(fotos.huellaAnverso(), fotos.huellaReverso(), persona.getCi(),
                    persona.getComplementoCi(), persona.getFechaNacimiento(), persona.getNombres(), persona.getApellidos());
            verificarSelfie(fotos, persona.getCi());
            guardar(persona, fotos);
            motivo = observacionSelfie(fotos);
            if (motivo == null && persona.getCarnetVencimiento() == null) {
                motivo = "No se pudo leer hasta cuándo vale el carnet";
            }
        } else {
            byte[] guardado = leerArchivo(persona.getCarnetAnversoUrl());
            LecturaSelfieResponse lectura = selfieConAnversoGuardado(persona, selfie, guardado, null);
            if (lectura.disponible() && !lectura.aceptada()) {
                throw new NegocioException(lectura.motivo());
            }
            guardarSelfie(persona, procesarSelfie(selfie));
            if (persona.getCarnetVencimiento() == null) {
                // Cuentas de antes: se lee hasta cuando vale el carnet en el anverso que ya tenia.
                LecturaDocumentoResponse delAnverso = lecturaDocumentoService.leerGuardada(guardado,
                        DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
                persona.setCarnetVencimiento(delAnverso.vencimiento());
            }
            motivo = !lectura.disponible() ? MOTIVO_SELFIE_SIN_REVISAR : lectura.observacion();
        }
        if (motivo != null) {
            observarSi(persona, PREFIJO_CUENTA_EXISTENTE + motivo);
        }
        return respuesta(usuario);
    }

    /**
     * Revisa la foto con el carnet apenas se toma, comparandola con el anverso guardado (cuenta que solo
     * debe subir esa foto). No guarda nada: la misma foto enviada despues usa esta revision.
     */
    @Transactional(readOnly = true)
    public LecturaSelfieResponse revisarSelfieCuenta(Long idUsuario, MultipartFile selfie) {
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new CredencialesInvalidasException("Credenciales invalidas"));
        Persona persona = usuario.getPersona();
        if (persona.getCi() == null || persona.getCi().isBlank()) {
            throw new NegocioException("Primero registra tu carnet");
        }
        if (!tieneCarnet(persona)) {
            throw new NegocioException(MENSAJE_FALTAN_FOTOS);
        }
        return selfieConAnversoGuardado(persona, selfie, leerArchivo(persona.getCarnetAnversoUrl()),
                "usuario:" + idUsuario);
    }

    /**
     * Revision de la foto con el carnet contra el anverso guardado; ademas el numero debe ser el CI de la
     * persona. [limite]: clave del limite de lecturas (null = sin limite).
     */
    private LecturaSelfieResponse selfieConAnversoGuardado(Persona persona, MultipartFile selfie, byte[] anverso,
            String limite) {
        if (selfie == null || selfie.isEmpty()) {
            throw new NegocioException("Falta tu foto con el carnet");
        }
        if (selfie.getSize() > AlmacenamientoArchivos.TAMANO_MAXIMO_IMAGEN * 2) {
            throw new NegocioException("La foto supera los 10 MB");
        }
        LecturaSelfieResponse lectura = lecturaDocumentoService.leerSelfie(bytesDe(selfie),
                selfie.getContentType() == null ? "image/jpeg" : selfie.getContentType(), anverso, limite);
        if (lectura.aceptada() && lectura.numero() != null && !lectura.numero().equals(persona.getCi().trim())) {
            return LecturaSelfieResponse.rechazada("El carnet de tu foto no es el tuyo: debe ser el carnet N° "
                    + persona.getCi().trim() + ".");
        }
        return lectura;
    }

    /** El carnet de la persona ya vencio (se sabe solo si se leyo su "Valida hasta"). */
    public static boolean carnetVencido(Persona persona) {
        return persona.getCarnetVencimiento() != null && persona.getCarnetVencimiento().isBefore(LocalDate.now());
    }

    private byte[] leerArchivo(String ruta) {
        try (var entrada = almacenamientoArchivos.leer(ruta).getInputStream()) {
            return entrada.readAllBytes();
        } catch (IOException e) {
            throw new NegocioException("No se pudo leer la foto de tu carnet guardada");
        }
    }

    private static byte[] bytesDe(MultipartFile foto) {
        try {
            return foto.getBytes();
        } catch (IOException e) {
            throw new NegocioException("No se pudo leer la foto con tu carnet");
        }
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
            case "selfie" -> persona.getCarnetSelfieUrl();
            default -> throw new NegocioException("Lado del carnet no valido: " + lado);
        };
        if (ruta == null || !almacenamientoArchivos.existe(ruta)) {
            throw new RecursoNoEncontradoException("selfie".equals(lado) ? "La persona no subio su foto con el carnet"
                    : "La persona no registro la foto del " + lado + " de su carnet");
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
