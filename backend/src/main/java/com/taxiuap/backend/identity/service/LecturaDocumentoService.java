package com.taxiuap.backend.identity.service;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.text.Normalizer;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.dto.LecturaDocumentoResponse;
import com.taxiuap.backend.identity.dto.LecturaSelfieResponse;
import com.taxiuap.backend.identity.dto.ReglasRegistro;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.enums.DocumentoIdentidad;
import com.taxiuap.backend.identity.enums.LadoDocumento;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.ia.IaNoDisponibleException;
import com.taxiuap.backend.shared.ia.ImagenIa;
import com.taxiuap.backend.shared.ia.LectorIa;

import tools.jackson.core.JacksonException;
import tools.jackson.databind.json.JsonMapper;

/**
 * Lectura del carnet y de la licencia con IA (LectorIa: Claude y, si no responde, Gemini; una foto
 * por vez) y verificacion de los datos que llegan al registrar.
 *
 * Cada lectura aceptada se guarda en memoria unas horas con la huella (SHA-256) de la foto. Al
 * registrar, la app manda las mismas fotos: si el servidor las leyo, los datos del registro deben ser
 * los leidos (no se pueden cambiar a mano) y el conductor queda aprobado solo si la licencia leida
 * aqui coincide con su carnet. Si no hay lectura del servidor (IA sin llave o caida, la app leyo con
 * ML Kit) se acepta lo que manda la app y el conductor queda PENDIENTE para el administrador.
 */
@Service
public class LecturaDocumentoService {

    private static final Logger log = LoggerFactory.getLogger(LecturaDocumentoService.class);

    private static final Duration VIGENCIA_LECTURA = Duration.ofHours(3);
    private static final int MAXIMO_LECTURAS_GUARDADAS = 5000;
    private static final Duration VENTANA_LIMITE = Duration.ofHours(1);
    private static final java.time.format.DateTimeFormatter FORMATO_FECHA =
            java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final LectorIa lector;
    private final JsonMapper json;
    private final int lecturasPorHora;
    private final String instrucciones;
    private final String instruccionesSelfie;
    private final Map<String, Object> esquema = esquema();
    private final Map<String, Object> esquemaSelfie = esquemaSelfie();

    private record Guardada(DocumentoIdentidad documento, LadoDocumento lado, LecturaDocumentoResponse lectura,
            Instant vence) {
    }

    private record SelfieGuardada(LecturaSelfieResponse lectura, Instant vence) {
    }

    private final Map<String, Guardada> lecturas = new ConcurrentHashMap<>();
    private final Map<String, SelfieGuardada> selfies = new ConcurrentHashMap<>();
    private final Map<String, Deque<Instant>> pedidosPorIp = new ConcurrentHashMap<>();

    /** Respuesta de la IA (Claude o Gemini) tal como la pide el esquema. */
    record LecturaIa(String documento, String formato, Boolean legible, String problema, String numero,
            String complemento, String nombres, String apellidos, String nombreCompleto, Boolean nombreSeparado,
            Boolean nombreCortado, String fechaNacimiento, String categoria, String vencimiento,
            Boolean sinVencimiento) {
    }

    /** Respuesta de la IA sobre la foto con el carnet. */
    record SelfieIa(Boolean caraVisible, Boolean carnetVisible, String ladoCarnet, String numero,
            String nombreCompleto, Boolean pantallaOImpresion, Boolean caraCoincide, Boolean legible,
            String problema) {
    }

    public LecturaDocumentoService(LectorIa lector, JsonMapper json,
            @Value("${taxiuap.gemini.lecturas-por-hora:40}") int lecturasPorHora) {
        this.lector = lector;
        this.json = json;
        this.lecturasPorHora = lecturasPorHora;
        this.instrucciones = texto("gemini/lectura_documento.txt");
        this.instruccionesSelfie = texto("gemini/selfie_carnet.txt");
    }

    private static String texto(String ruta) {
        try (InputStream entrada = new ClassPathResource(ruta).getInputStream()) {
            return new String(entrada.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new IllegalStateException("Falta " + ruta, e);
        }
    }

    /** Huella SHA-256 de los bytes de una foto, para reconocerla al registrar. */
    public static String huella(byte[] bytes) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    public static String huella(MultipartFile foto) {
        try {
            return foto == null || foto.isEmpty() ? null : huella(foto.getBytes());
        } catch (IOException e) {
            return null;
        }
    }

    /** Lee una foto del [documento] del [lado] pedido. */
    public LecturaDocumentoResponse leer(MultipartFile foto, DocumentoIdentidad documento, LadoDocumento lado,
            String ip) {
        if (foto == null || foto.isEmpty()) {
            throw new NegocioException("Falta la foto");
        }
        if (foto.getSize() > AlmacenamientoArchivos.TAMANO_MAXIMO_IMAGEN * 2) {
            throw new NegocioException("La foto supera los 10 MB");
        }
        if (!lector.configurado()) {
            return LecturaDocumentoResponse.noDisponible();
        }
        String clave = huella(bytesDe(foto));
        Guardada previa = vigente(clave);
        if (previa != null && previa.documento() == documento && previa.lado() == lado) {
            return previa.lectura();
        }
        controlarLimite(ip);
        return leerBytes(bytesDe(foto), tipoDe(foto), documento, lado);
    }

    /**
     * Lee una foto que ya esta guardada en el servidor (por ejemplo el anverso del carnet de una cuenta
     * de antes, para conocer su vencimiento). Sin limite por IP.
     */
    public LecturaDocumentoResponse leerGuardada(byte[] bytes, DocumentoIdentidad documento, LadoDocumento lado) {
        if (!lector.configurado() || bytes == null) {
            return LecturaDocumentoResponse.noDisponible();
        }
        return leerBytes(bytes, "image/jpeg", documento, lado);
    }

    private LecturaDocumentoResponse leerBytes(byte[] bytes, String tipo, DocumentoIdentidad documento,
            LadoDocumento lado) {
        String clave = huella(bytes);
        LecturaIa leida;
        try {
            String texto = lector.leerImagen(instrucciones, "Lee este documento.", bytes, tipo, esquema);
            leida = json.readValue(texto, LecturaIa.class);
        } catch (IaNoDisponibleException e) {
            return LecturaDocumentoResponse.noDisponible();
        } catch (JacksonException e) {
            log.warn("La IA devolvio un JSON que no se pudo leer: {}", e.getOriginalMessage());
            return LecturaDocumentoResponse.noDisponible();
        }
        LecturaDocumentoResponse lectura = evaluar(leida, documento, lado);
        if (lectura.aceptada()) {
            guardar(clave, new Guardada(documento, lado, lectura, Instant.now().plus(VIGENCIA_LECTURA)));
        }
        return lectura;
    }

    private static byte[] bytesDe(MultipartFile foto) {
        try {
            return foto.getBytes();
        } catch (IOException e) {
            throw new NegocioException("No se pudo leer la foto");
        }
    }

    private static String tipoDe(MultipartFile foto) {
        return foto.getContentType() != null && foto.getContentType().startsWith("image/")
                ? foto.getContentType() : "image/jpeg";
    }

    // ---------------------------------------------------------------- foto con el carnet

    /**
     * Revisa la foto de la persona sosteniendo su carnet. [anverso] (opcional) es la foto del anverso que
     * tomo antes: ayuda a comparar la cara y su numero debe ser el mismo.
     */
    public LecturaSelfieResponse leerSelfie(MultipartFile foto, MultipartFile anverso, String ip) {
        if (foto == null || foto.isEmpty()) {
            throw new NegocioException("Falta la foto con tu carnet");
        }
        if (foto.getSize() > AlmacenamientoArchivos.TAMANO_MAXIMO_IMAGEN * 2) {
            throw new NegocioException("La foto supera los 10 MB");
        }
        if (!lector.configurado()) {
            return LecturaSelfieResponse.noDisponible();
        }
        byte[] bytesAnverso = anverso == null || anverso.isEmpty() ? null : bytesDe(anverso);
        String clave = claveSelfie(huella(bytesDe(foto)), bytesAnverso == null ? null : huella(bytesAnverso));
        SelfieGuardada previa = selfieVigente(clave);
        if (previa != null) {
            return previa.lectura();
        }
        controlarLimite(ip);
        return revisarSelfie(bytesDe(foto), tipoDe(foto), bytesAnverso, bytesAnverso == null ? null : tipoDe(anverso));
    }

    /** Igual que leerSelfie, con el anverso ya guardado en el servidor (cuentas de antes). */
    public LecturaSelfieResponse leerSelfie(byte[] foto, String tipo, byte[] anverso) {
        if (!lector.configurado()) {
            return LecturaSelfieResponse.noDisponible();
        }
        String clave = claveSelfie(huella(foto), anverso == null ? null : huella(anverso));
        SelfieGuardada previa = selfieVigente(clave);
        return previa != null ? previa.lectura() : revisarSelfie(foto, tipo, anverso, "image/jpeg");
    }

    private LecturaSelfieResponse revisarSelfie(byte[] foto, String tipo, byte[] anverso, String tipoAnverso) {
        List<ImagenIa> imagenes = anverso == null
                ? List.of(new ImagenIa(foto, tipo))
                : List.of(new ImagenIa(foto, tipo), new ImagenIa(anverso, tipoAnverso));
        SelfieIa leida;
        try {
            String texto = lector.leerImagenes(instruccionesSelfie, anverso == null
                    ? "Revisa la foto con el carnet."
                    : "La primera imagen es la foto con el carnet y la segunda el anverso del carnet.",
                    imagenes, esquemaSelfie);
            leida = json.readValue(texto, SelfieIa.class);
        } catch (IaNoDisponibleException e) {
            return LecturaSelfieResponse.noDisponible();
        } catch (JacksonException e) {
            log.warn("La IA devolvio un JSON que no se pudo leer (foto con el carnet): {}", e.getOriginalMessage());
            return LecturaSelfieResponse.noDisponible();
        }
        String numeroAnverso = null;
        if (anverso != null) {
            LecturaDocumentoResponse delAnverso = lectura(huella(anverso), DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
            numeroAnverso = delAnverso == null ? null : delAnverso.numero();
        }
        LecturaSelfieResponse lectura = evaluarSelfie(leida, numeroAnverso);
        if (lectura.aceptada()) {
            guardarSelfie(claveSelfie(huella(foto), anverso == null ? null : huella(anverso)),
                    new SelfieGuardada(lectura, Instant.now().plus(VIGENCIA_LECTURA)));
        }
        return lectura;
    }

    static LecturaSelfieResponse evaluarSelfie(SelfieIa g, String numeroAnverso) {
        String problema = g.problema() == null || g.problema().isBlank() ? null : g.problema().trim();
        if (!Boolean.TRUE.equals(g.caraVisible()) || !Boolean.TRUE.equals(g.carnetVisible())) {
            return LecturaSelfieResponse.rechazada(problema != null ? problema
                    : "En la foto deben verse tu cara y tu carnet (el lado con tu foto). Vuelve a tomarla.");
        }
        if (!"ANVERSO".equals(g.ladoCarnet())) {
            return LecturaSelfieResponse.rechazada("Muestra el lado de tu carnet que tiene tu foto y vuelve a tomarla.");
        }
        String numero = soloDigitos(g.numero());
        if (!Boolean.TRUE.equals(g.legible()) || numero == null) {
            return LecturaSelfieResponse.rechazada(problema != null ? problema
                    : "Acerca el carnet a la cámara: debe leerse su número. Vuelve a tomar la foto.");
        }
        if (numeroAnverso != null && !numeroAnverso.equals(numero)) {
            return LecturaSelfieResponse.rechazada("El carnet de esta foto no es el mismo de las fotos de tu carnet.");
        }
        String observacion = Boolean.TRUE.equals(g.pantallaOImpresion())
                ? "La foto con el carnet parece tomada a otra foto o a una pantalla"
                : Boolean.FALSE.equals(g.caraCoincide())
                        ? "La cara de la foto con el carnet no se parece a la foto del carnet" : null;
        return new LecturaSelfieResponse(true, true, null, numero, observacion);
    }

    /** Lo que el servidor reviso de la foto con el carnet (null si no la reviso). */
    public LecturaSelfieResponse selfie(String huellaSelfie, String huellaAnverso) {
        if (huellaSelfie == null) {
            return null;
        }
        SelfieGuardada guardada = selfieVigente(claveSelfie(huellaSelfie, huellaAnverso));
        if (guardada == null && huellaAnverso != null) {
            // La app pudo revisarla sin mandar el anverso.
            guardada = selfieVigente(claveSelfie(huellaSelfie, null));
        }
        return guardada == null ? null : guardada.lectura();
    }

    /** Vencimiento del carnet leido por el servidor en la foto del anverso (null si no la leyo o no vence). */
    public LocalDate vencimientoCarnet(String huellaAnverso) {
        LecturaDocumentoResponse anverso = lectura(huellaAnverso, DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        return anverso == null ? null : anverso.vencimiento();
    }

    private static String claveSelfie(String huellaSelfie, String huellaAnverso) {
        return huellaSelfie + ":" + (huellaAnverso == null ? "-" : huellaAnverso);
    }

    private SelfieGuardada selfieVigente(String clave) {
        SelfieGuardada guardada = selfies.get(clave);
        if (guardada != null && guardada.vence().isBefore(Instant.now())) {
            selfies.remove(clave);
            return null;
        }
        return guardada;
    }

    private void guardarSelfie(String clave, SelfieGuardada guardada) {
        if (selfies.size() >= MAXIMO_LECTURAS_GUARDADAS) {
            Instant ahora = Instant.now();
            selfies.values().removeIf(g -> g.vence().isBefore(ahora));
        }
        if (selfies.size() < MAXIMO_LECTURAS_GUARDADAS) {
            selfies.put(clave, guardada);
        }
    }

    // ---------------------------------------------------------------- evaluacion de la lectura

    static LecturaDocumentoResponse evaluar(LecturaIa g, DocumentoIdentidad documento, LadoDocumento lado) {
        String esperado = documento.name() + "_" + lado.name();
        String leido = g.documento() == null ? "OTRO" : g.documento();
        if (!esperado.equals(leido)) {
            return LecturaDocumentoResponse.rechazada(motivoOtroDocumento(documento, lado, leido));
        }
        if (!Boolean.TRUE.equals(g.legible())) {
            return LecturaDocumentoResponse.rechazada(g.problema() == null || g.problema().isBlank()
                    ? "No se lee bien la foto. Vuelve a tomarla de frente, con buena luz, sin reflejos y con todo el "
                            + nombreDocumento(documento) + " a la vista."
                    : g.problema().trim());
        }
        String numero = soloDigitos(g.numero());
        String complemento = complemento(g.complemento());
        String nombres = nombre(g.nombres());
        String apellidos = nombre(g.apellidos());
        boolean separado = Boolean.TRUE.equals(g.nombreSeparado()) && nombres != null && apellidos != null;
        String completo = separado ? nombres + " " + apellidos : nombre(g.nombreCompleto());
        // Carnet antiguo: el corte lo propone la IA; vale solo si son las mismas palabras del nombre impreso.
        if (!separado && (nombres == null || apellidos == null || completo == null
                || !sinTildes(nombres + " " + apellidos).equals(sinTildes(completo)))) {
            nombres = null;
            apellidos = null;
        }
        LocalDate nacimiento = fecha(g.fechaNacimiento());
        String categoria = categoria(g.categoria());
        LocalDate vencimiento = fecha(g.vencimiento());

        boolean sinVencimiento = Boolean.TRUE.equals(g.sinVencimiento());
        if (sinVencimiento) {
            vencimiento = null;
        }
        String falta = switch (esperado) {
            case "CARNET_ANVERSO" -> numero == null ? "el número del carnet"
                    : vencimiento == null && !sinVencimiento ? "hasta cuándo vale tu carnet (Válida hasta)" : null;
            case "CARNET_REVERSO" -> completo == null ? "tu nombre" : nacimiento == null ? "tu fecha de nacimiento" : null;
            case "LICENCIA_ANVERSO" -> numero == null ? "el número de licencia"
                    : !separado ? "tu nombre (Nombres, Apellidos)" : null;
            default -> categoria == null ? "la categoría de la licencia"
                    : vencimiento == null ? "la fecha de vencimiento" : null;
        };
        if (falta != null) {
            return LecturaDocumentoResponse.rechazada("No se pudo leer " + falta + " en la foto. Vuelve a tomarla de "
                    + "frente, con buena luz, sin reflejos y con todo el " + nombreDocumento(documento) + " a la vista.");
        }
        if (vencimiento != null && vencimiento.isBefore(LocalDate.now())) {
            return LecturaDocumentoResponse.vencido(documento == DocumentoIdentidad.CARNET
                    ? "Tu carnet venció el " + FORMATO_FECHA.format(vencimiento) + ". Renuévalo en el SEGIP para continuar."
                    : "Tu licencia venció el " + FORMATO_FECHA.format(vencimiento) + ". Renuévala para continuar.",
                    vencimiento);
        }
        return new LecturaDocumentoResponse(true, true, null, g.formato(), numero, complemento, nombres, apellidos,
                completo, separado, separado && Boolean.TRUE.equals(g.nombreCortado()), nacimiento, categoria,
                vencimiento);
    }

    private static String nombreDocumento(DocumentoIdentidad documento) {
        return documento == DocumentoIdentidad.CARNET ? "carnet" : "licencia";
    }

    private static String motivoOtroDocumento(DocumentoIdentidad documento, LadoDocumento lado, String leido) {
        String carnet = documento == DocumentoIdentidad.CARNET ? "carnet de identidad" : "licencia de conducir";
        if (leido.startsWith(documento.name() + "_")) {
            return lado == LadoDocumento.ANVERSO
                    ? "Esta foto es el reverso de tu " + carnet + ". Aquí va el anverso: el lado con tu foto."
                    : "Esta foto es el anverso de tu " + carnet + ". Aquí va el reverso: el lado de atrás.";
        }
        if (!"OTRO".equals(leido)) {
            return documento == DocumentoIdentidad.CARNET
                    ? "Esta foto es de una licencia de conducir. Aquí va tu carnet de identidad."
                    : "Esta foto es de un carnet de identidad. Aquí va tu licencia de conducir.";
        }
        return "Esta foto no es el " + (lado == LadoDocumento.ANVERSO ? "anverso" : "reverso") + " de un " + carnet
                + " boliviano. Tómala de frente, con buena luz y con todo el documento a la vista.";
    }

    private static String soloDigitos(String valor) {
        if (valor == null) {
            return null;
        }
        String digitos = valor.replaceAll("\\D", "");
        return digitos.length() >= 5 && digitos.length() <= 10 ? digitos : null;
    }

    private static String complemento(String valor) {
        if (valor == null) {
            return null;
        }
        String limpio = valor.trim().toUpperCase(Locale.ROOT);
        return limpio.matches(ReglasRegistro.PATRON_COMPLEMENTO) && limpio.matches("^(?=.*\\d)[0-9A-Z]{2}$")
                ? limpio : null;
    }

    private static String nombre(String valor) {
        if (valor == null) {
            return null;
        }
        String limpio = valor.replace(',', ' ').replaceAll("\\s+", " ").trim().toUpperCase(Locale.ROOT);
        return limpio.isEmpty() || !limpio.matches(ReglasRegistro.PATRON_NOMBRE) ? null : limpio;
    }

    private static String categoria(String valor) {
        if (valor == null) {
            return null;
        }
        String limpio = valor.trim().toUpperCase(Locale.ROOT);
        return limpio.matches("^[PMABC]$") ? limpio : null;
    }

    private static LocalDate fecha(String valor) {
        if (valor == null || valor.isBlank()) {
            return null;
        }
        try {
            return LocalDate.parse(valor.trim());
        } catch (DateTimeParseException e) {
            return null;
        }
    }

    // ---------------------------------------------------------------- verificacion al registrar

    /**
     * Los datos del carnet que llegan al registrar deben ser los que el servidor leyo de esas mismas
     * fotos. Sin lectura del servidor (ML Kit, web sin Gemini) no se compara nada.
     */
    public void verificarCarnet(String huellaAnverso, String huellaReverso, String ci, String complemento,
            LocalDate fechaNacimiento, String nombres, String apellidos) {
        LecturaDocumentoResponse anverso = lectura(huellaAnverso, DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        LecturaDocumentoResponse reverso = lectura(huellaReverso, DocumentoIdentidad.CARNET, LadoDocumento.REVERSO);
        if (anverso == null && reverso == null) {
            return;
        }
        String numero = primero(anverso == null ? null : anverso.numero(), reverso == null ? null : reverso.numero());
        if (numero != null && (ci == null || !numero.equals(ci.trim()))) {
            throw noCoincide("el número de carnet");
        }
        String complementoLeido = anverso == null ? null : anverso.complemento();
        if (complementoLeido != null && !complementoLeido.equalsIgnoreCase(complemento == null ? "" : complemento.trim())) {
            throw noCoincide("el complemento");
        }
        LocalDate fecha = reverso != null && reverso.fechaNacimiento() != null ? reverso.fechaNacimiento()
                : anverso == null ? null : anverso.fechaNacimiento();
        if (fecha != null && !fecha.equals(fechaNacimiento)) {
            throw noCoincide("la fecha de nacimiento");
        }
        String escrito = sinTildes(String.join(" ", nombres == null ? "" : nombres, apellidos == null ? "" : apellidos));
        if (anverso != null && anverso.nombreCompleto() != null) {
            // Carnet nuevo: NOMBRES y APELLIDOS impresos en el anverso.
            if (!escrito.equals(sinTildes(anverso.nombreCompleto()))) {
                throw noCoincide("tu nombre");
            }
        } else if (reverso != null && reverso.nombreCortado()) {
            // MRZ cortada: los apellidos estan completos y los nombres pueden estar recortados.
            if (!sinTildes(apellidos).equals(sinTildes(reverso.apellidos()))
                    || !sinTildes(nombres).startsWith(sinTildes(reverso.nombres()))) {
                throw noCoincide("tu nombre");
            }
        } else if (reverso != null && reverso.nombreCompleto() != null && !escrito.equals(sinTildes(reverso.nombreCompleto()))) {
            throw noCoincide("tu nombre");
        }
    }

    /** Los datos de la licencia del registro deben ser los leidos de sus fotos (si el servidor las leyo). */
    public void verificarLicencia(String huellaAnverso, String huellaReverso, String numeroLicencia, String categoria,
            LocalDate vencimiento) {
        LecturaDocumentoResponse anverso = lectura(huellaAnverso, DocumentoIdentidad.LICENCIA, LadoDocumento.ANVERSO);
        LecturaDocumentoResponse reverso = lectura(huellaReverso, DocumentoIdentidad.LICENCIA, LadoDocumento.REVERSO);
        if (anverso == null && reverso == null) {
            return;
        }
        String numero = primero(anverso == null ? null : anverso.numero(), reverso == null ? null : reverso.numero());
        String enviado = numeroLicencia == null ? "" : numeroLicencia.split("-")[0].replaceAll("\\D", "");
        if (numero != null && !numero.equals(enviado)) {
            throw noCoincideLicencia("el número de licencia");
        }
        String categoriaLeida = primero(reverso == null ? null : reverso.categoria(), anverso == null ? null : anverso.categoria());
        if (categoriaLeida != null && !categoriaLeida.equalsIgnoreCase(categoria == null ? "" : categoria.trim())) {
            throw noCoincideLicencia("la categoría");
        }
        LocalDate vence = reverso != null && reverso.vencimiento() != null ? reverso.vencimiento()
                : anverso == null ? null : anverso.vencimiento();
        if (vence != null && !vence.equals(vencimiento)) {
            throw noCoincideLicencia("la fecha de vencimiento");
        }
    }

    /**
     * La licencia leida por el servidor es de moto, esta vigente, su numero es el CI de la persona (con
     * su complemento si lo tiene) y "Nombres, Apellidos" es el mismo nombre del carnet.
     */
    public boolean licenciaCoincide(String huellaAnverso, String huellaReverso, Persona persona) {
        LecturaDocumentoResponse anverso = lectura(huellaAnverso, DocumentoIdentidad.LICENCIA, LadoDocumento.ANVERSO);
        LecturaDocumentoResponse reverso = lectura(huellaReverso, DocumentoIdentidad.LICENCIA, LadoDocumento.REVERSO);
        if (anverso == null || reverso == null || persona.getCi() == null) {
            return false;
        }
        String complementoCi = persona.getComplementoCi() == null ? "" : persona.getComplementoCi().trim();
        boolean numero = persona.getCi().trim().equals(anverso.numero())
                && (anverso.complemento() == null || anverso.complemento().equalsIgnoreCase(complementoCi));
        boolean moto = ReglasRegistro.CATEGORIA_MOTO.equals(reverso.categoria());
        LocalDate vence = reverso.vencimiento() != null ? reverso.vencimiento() : anverso.vencimiento();
        boolean vigente = vence != null && !vence.isBefore(LocalDate.now());
        boolean nombre = sinTildes(anverso.nombreCompleto())
                .equals(sinTildes(persona.getNombres() + " " + persona.getApellidos()));
        return numero && moto && vigente && nombre;
    }

    private static NegocioException noCoincide(String dato) {
        return new NegocioException("Los datos no coinciden con las fotos de tu carnet (" + dato
                + "). Vuelve a tomar las fotos.");
    }

    private static NegocioException noCoincideLicencia(String dato) {
        return new NegocioException("Los datos no coinciden con las fotos de tu licencia (" + dato
                + "). Vuelve a tomar las fotos.");
    }

    private static String primero(String a, String b) {
        return a != null ? a : b;
    }

    /** Mayusculas sin tildes ni espacios de mas: "Pérez  Ñuflo" -> "PEREZ NUFLO". */
    static String sinTildes(String texto) {
        if (texto == null) {
            return "";
        }
        return Normalizer.normalize(texto, Normalizer.Form.NFD).replaceAll("\\p{M}", "")
                .replaceAll("\\s+", " ").trim().toUpperCase(Locale.ROOT);
    }

    // ---------------------------------------------------------------- memoria y limite

    private LecturaDocumentoResponse lectura(String clave, DocumentoIdentidad documento, LadoDocumento lado) {
        Guardada guardada = clave == null ? null : vigente(clave);
        return guardada != null && guardada.documento() == documento && guardada.lado() == lado
                ? guardada.lectura() : null;
    }

    private Guardada vigente(String clave) {
        Guardada guardada = lecturas.get(clave);
        if (guardada != null && guardada.vence().isBefore(Instant.now())) {
            lecturas.remove(clave);
            return null;
        }
        return guardada;
    }

    private void guardar(String clave, Guardada guardada) {
        if (lecturas.size() >= MAXIMO_LECTURAS_GUARDADAS) {
            Instant ahora = Instant.now();
            lecturas.values().removeIf(g -> g.vence().isBefore(ahora));
        }
        if (lecturas.size() < MAXIMO_LECTURAS_GUARDADAS) {
            lecturas.put(clave, guardada);
        }
    }

    /** Cada IP puede pedir [lecturasPorHora] lecturas por hora (cuida la cuota de la llave). */
    private void controlarLimite(String ip) {
        Instant ahora = Instant.now();
        Deque<Instant> pedidos = pedidosPorIp.computeIfAbsent(ip == null ? "?" : ip, k -> new ArrayDeque<>());
        synchronized (pedidos) {
            while (!pedidos.isEmpty() && pedidos.peekFirst().isBefore(ahora.minus(VENTANA_LIMITE))) {
                pedidos.pollFirst();
            }
            if (pedidos.size() >= lecturasPorHora) {
                throw new NegocioException("Hiciste muchas lecturas de fotos seguidas. Espera unos minutos e intenta de nuevo.");
            }
            pedidos.addLast(ahora);
        }
        if (pedidosPorIp.size() > 10_000) {
            pedidosPorIp.entrySet().removeIf(e -> e.getValue().isEmpty());
        }
    }

    // ---------------------------------------------------------------- esquema de la respuesta

    private static Map<String, Object> tipo(String tipo, boolean nulo) {
        Map<String, Object> campo = new LinkedHashMap<>();
        campo.put("type", tipo);
        if (nulo) {
            campo.put("nullable", true);
        }
        return campo;
    }

    private static Map<String, Object> esquema() {
        Map<String, Object> propiedades = new LinkedHashMap<>();
        Map<String, Object> documento = tipo("STRING", false);
        documento.put("enum", List.of("CARNET_ANVERSO", "CARNET_REVERSO", "LICENCIA_ANVERSO", "LICENCIA_REVERSO", "OTRO"));
        propiedades.put("documento", documento);
        Map<String, Object> formato = tipo("STRING", false);
        formato.put("enum", List.of("NUEVO", "ANTIGUO", "LICENCIA", "OTRO"));
        propiedades.put("formato", formato);
        propiedades.put("legible", tipo("BOOLEAN", false));
        propiedades.put("problema", tipo("STRING", true));
        propiedades.put("numero", tipo("STRING", true));
        propiedades.put("complemento", tipo("STRING", true));
        propiedades.put("nombres", tipo("STRING", true));
        propiedades.put("apellidos", tipo("STRING", true));
        propiedades.put("nombreCompleto", tipo("STRING", true));
        propiedades.put("nombreSeparado", tipo("BOOLEAN", false));
        propiedades.put("nombreCortado", tipo("BOOLEAN", false));
        propiedades.put("fechaNacimiento", tipo("STRING", true));
        propiedades.put("categoria", tipo("STRING", true));
        propiedades.put("vencimiento", tipo("STRING", true));
        propiedades.put("sinVencimiento", tipo("BOOLEAN", true));
        Map<String, Object> raiz = tipo("OBJECT", false);
        raiz.put("properties", propiedades);
        raiz.put("required", List.of("documento", "formato", "legible", "nombreSeparado", "nombreCortado"));
        raiz.put("propertyOrdering", List.copyOf(propiedades.keySet()));
        return raiz;
    }

    private static Map<String, Object> esquemaSelfie() {
        Map<String, Object> propiedades = new LinkedHashMap<>();
        propiedades.put("caraVisible", tipo("BOOLEAN", false));
        propiedades.put("carnetVisible", tipo("BOOLEAN", false));
        Map<String, Object> lado = tipo("STRING", false);
        lado.put("enum", List.of("ANVERSO", "REVERSO", "NINGUNO"));
        propiedades.put("ladoCarnet", lado);
        propiedades.put("numero", tipo("STRING", true));
        propiedades.put("nombreCompleto", tipo("STRING", true));
        propiedades.put("pantallaOImpresion", tipo("BOOLEAN", false));
        propiedades.put("caraCoincide", tipo("BOOLEAN", true));
        propiedades.put("legible", tipo("BOOLEAN", false));
        propiedades.put("problema", tipo("STRING", true));
        Map<String, Object> raiz = tipo("OBJECT", false);
        raiz.put("properties", propiedades);
        raiz.put("required", List.of("caraVisible", "carnetVisible", "ladoCarnet", "pantallaOImpresion", "legible"));
        raiz.put("propertyOrdering", List.copyOf(propiedades.keySet()));
        return raiz;
    }
}
