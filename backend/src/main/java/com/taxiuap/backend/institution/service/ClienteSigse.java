package com.taxiuap.backend.institution.service;

import java.net.http.HttpClient;
import java.time.Duration;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.Base64;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import com.taxiuap.backend.institution.dto.DatosSigse;
import com.taxiuap.backend.shared.exception.NegocioException;

import lombok.extern.slf4j.Slf4j;

/**
 * Consulta de un estudiante por RU en el SIGSE de la UAP (POST {"ru": "..."} con el encabezado
 * x-api-key: "key <llave>"). La URL y la llave van solo en el servidor (SIGSE_URL y SIGSE_API_KEY en
 * el .env); la app nunca las ve. El SIGSE responde HTTP 200 siempre: el resultado real va en
 * status / ok del cuerpo, y un RU inexistente llega como status 500.
 */
@Slf4j
@Component
public class ClienteSigse {

    private static final String NO_DISPONIBLE =
            "No pudimos consultar el sistema de la UAP en este momento. Intenta de nuevo en unos minutos.";
    private static final String SIN_CONFIGURAR =
            "La verificacion de estudiantes UAP no esta habilitada en este servidor. Avisa al administrador.";
    private static final String SIN_CONEXION =
            "El servidor no pudo conectarse con el sistema de la UAP. Intenta de nuevo en unos minutos.";
    private static final String LLAVE_RECHAZADA =
            "El sistema de la UAP rechazo la consulta del servidor. Avisa al administrador.";

    private final RestClient cliente;
    private final String url;
    private final String llave;

    public ClienteSigse(
            @Value("${taxiuap.sigse.url:${SIGSE_URL:}}") String url,
            @Value("${taxiuap.sigse.api-key:${SIGSE_API_KEY:}}") String llave,
            @Value("${taxiuap.sigse.segundos-espera:15}") int segundosEspera) {
        this.url = url == null ? "" : url.trim();
        String valor = llave == null ? "" : llave.trim();
        this.llave = valor.isEmpty() || valor.startsWith("key ") ? valor : "key " + valor;
        HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
        JdkClientHttpRequestFactory fabrica = new JdkClientHttpRequestFactory(http);
        fabrica.setReadTimeout(Duration.ofSeconds(segundosEspera));
        this.cliente = RestClient.builder().requestFactory(fabrica).build();
        if (!configurado()) {
            log.warn("SIGSE sin configurar: falta SIGSE_URL o SIGSE_API_KEY en el .env. El registro y la "
                    + "verificacion de estudiantes UAP no funcionaran hasta agregarlas y reiniciar");
        }
    }

    public boolean configurado() {
        return !url.isEmpty() && !llave.isEmpty();
    }

    /**
     * Datos del RU, o vacio si el SIGSE dice que no existe. Lanza NegocioException si el SIGSE no
     * responde o rechaza la llave (no es culpa del estudiante).
     */
    public Optional<DatosSigse> consultar(String ru) {
        if (!configurado()) {
            log.warn("SIGSE sin configurar (SIGSE_URL / SIGSE_API_KEY)");
            throw new NegocioException(SIN_CONFIGURAR);
        }
        Map<?, ?> respuesta;
        try {
            respuesta = cliente.post()
                    .uri(url)
                    .header("x-api-key", llave)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of("ru", ru))
                    .retrieve()
                    .body(Map.class);
        } catch (ResourceAccessException e) {
            // DNS, conexion rechazada, certificado o tiempo de espera: el servidor no llega al SIGSE.
            log.warn("SIGSE sin conexion desde el servidor: {}", e.getMessage());
            throw new NegocioException(SIN_CONEXION);
        } catch (RestClientException e) {
            log.warn("SIGSE no respondio: {}", e.getMessage());
            throw new NegocioException(NO_DISPONIBLE);
        }
        if (respuesta == null) throw new NegocioException(NO_DISPONIBLE);
        int estado = respuesta.get("status") instanceof Number n ? n.intValue() : 0;
        if (Boolean.TRUE.equals(respuesta.get("ok")) && respuesta.get("data") instanceof Map<?, ?> data) {
            return Optional.of(convertir(data));
        }
        if (estado == 401 || estado == 403) {
            log.warn("SIGSE rechazo la llave: {} {}", estado, respuesta.get("mensaje"));
            throw new NegocioException(LLAVE_RECHAZADA);
        }
        // Un RU que no existe tambien llega como status 500 ("posiblemente el enlace no sea valido").
        log.info("SIGSE sin datos para el RU: {} {}", estado, respuesta.get("mensaje"));
        return Optional.empty();
    }

    static DatosSigse convertir(Map<?, ?> d) {
        return new DatosSigse(
                texto(d.get("ru")),
                texto(d.get("ci")),
                texto(d.get("nombres")),
                texto(d.get("apellido_paterno")),
                texto(d.get("apellido_materno")),
                fecha(d.get("fecha_nacimiento")),
                texto(d.get("correo")),
                texto(d.get("celular")),
                texto(d.get("carrera")),
                texto(d.get("facultad")),
                texto(d.get("plan")),
                entero(d.get("gestion")),
                entero(d.get("periodo")),
                texto(d.get("vigencia")),
                Boolean.TRUE.equals(d.get("estado_matriculacion")),
                foto(d.get("url_imagen")));
    }

    private static String texto(Object valor) {
        if (valor == null) return null;
        String t = valor.toString().trim();
        return t.isEmpty() ? null : t;
    }

    private static Integer entero(Object valor) {
        if (valor instanceof Number n) return n.intValue();
        try {
            return valor == null ? null : Integer.valueOf(valor.toString().trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static LocalDate fecha(Object valor) {
        try {
            return valor == null ? null : LocalDate.parse(valor.toString().trim().substring(0, 10));
        } catch (DateTimeParseException | IndexOutOfBoundsException e) {
            return null;
        }
    }

    /** "data:image/jpeg;base64,..." -> bytes de la imagen; null si no vino o no se puede leer. */
    private static byte[] foto(Object valor) {
        String t = texto(valor);
        if (t == null) return null;
        int coma = t.indexOf(',');
        String base64 = t.startsWith("data:") && coma > 0 ? t.substring(coma + 1) : t;
        try {
            byte[] bytes = Base64.getMimeDecoder().decode(base64);
            return bytes.length > 100 ? bytes : null;
        } catch (IllegalArgumentException e) {
            return null;
        }
    }
}
