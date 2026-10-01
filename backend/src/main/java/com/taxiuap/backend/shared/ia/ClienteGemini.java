package com.taxiuap.backend.shared.ia;

import java.net.http.HttpClient;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.client.BufferingClientHttpRequestFactory;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

/**
 * Cliente de la API de Gemini (Google AI Studio) para leer imagenes y devolver JSON con un esquema
 * fijo. La llave solo vive en el servidor (GEMINI_API_KEY): nunca va en la app.
 *
 * El modelo por defecto es el alias gemini-flash-latest, que Google mueve al Flash mas nuevo. El Flash
 * mas nuevo suele estar saturado (503 "high demand"): entonces se prueban los Flash anteriores y al final
 * gemini-flash-lite-latest (ver modelosRespaldo), hasta MAXIMO_MODELOS por lectura.
 */
@Component
public class ClienteGemini {

    private static final Logger log = LoggerFactory.getLogger(ClienteGemini.class);

    /** Flash estable: gemini-3.8-flash (sin -lite, -preview, -image, -tts...). */
    private static final Pattern FLASH_ESTABLE = Pattern.compile("^models/(gemini-(\\d+)(?:\\.(\\d+))?-flash)$");

    private final RestClient cliente;
    private final String apiKey;
    private final String modelo;
    private final String nivelRazonamiento;
    private volatile List<String> modelosRespaldo;

    /** Modelos que respondieron saturados: se saltan hasta la hora guardada. */
    private final Map<String, Instant> ocupados = new ConcurrentHashMap<>();

    /** Cuantos modelos se prueban por lectura como maximo (cada uno espera hasta segundos-espera). */
    private static final int MAXIMO_MODELOS = 4;
    private static final Duration PAUSA_MODELO_OCUPADO = Duration.ofMinutes(2);
    private static final Duration PAUSA_MODELO_INEXISTENTE = Duration.ofHours(12);

    public ClienteGemini(
            @Value("${taxiuap.gemini.api-key:${GEMINI_API_KEY:}}") String apiKey,
            @Value("${taxiuap.gemini.modelo:${GEMINI_MODELO:gemini-flash-latest}}") String modelo,
            @Value("${taxiuap.gemini.url:https://generativelanguage.googleapis.com/v1beta}") String url,
            @Value("${taxiuap.gemini.nivel-razonamiento:}") String nivelRazonamiento,
            @Value("${taxiuap.gemini.segundos-espera:25}") int segundosEspera) {
        this.apiKey = apiKey == null ? "" : apiKey.trim();
        this.modelo = modelo;
        this.nivelRazonamiento = nivelRazonamiento == null ? "" : nivelRazonamiento.trim();
        HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
        JdkClientHttpRequestFactory fabrica = new JdkClientHttpRequestFactory(http);
        fabrica.setReadTimeout(Duration.ofSeconds(segundosEspera));
        this.cliente = RestClient.builder()
                .baseUrl(url)
                // Cuerpo completo con Content-Length (sin esto el cliente JDK lo manda por partes).
                .requestFactory(new BufferingClientHttpRequestFactory(fabrica))
                .defaultHeader("x-goog-api-key", this.apiKey)
                .build();
    }

    /** Hay una llave configurada. */
    public boolean configurado() {
        return !apiKey.isEmpty();
    }

    /**
     * Envia una imagen con sus instrucciones y devuelve el texto JSON de la respuesta, que sigue
     * [esquema] (formato OpenAPI de Gemini).
     *
     * @throws GeminiNoDisponibleException sin llave, sin conexion, sin cuota o con la llave rechazada
     */
    public String leerImagen(String instrucciones, String pedido, byte[] imagen, String tipoMime,
            Map<String, Object> esquema) {
        if (!configurado()) {
            throw new GeminiNoDisponibleException("Falta GEMINI_API_KEY");
        }
        Map<String, Object> configuracion = new java.util.LinkedHashMap<>();
        configuracion.put("temperature", 0);
        configuracion.put("responseMimeType", "application/json");
        configuracion.put("responseSchema", esquema);
        if (!nivelRazonamiento.isEmpty()) {
            configuracion.put("thinkingConfig", Map.of("thinkingLevel", nivelRazonamiento));
        }
        Map<String, Object> cuerpo = Map.of(
                "systemInstruction", Map.of("parts", List.of(Map.of("text", instrucciones))),
                "contents", List.of(Map.of("role", "user", "parts", List.of(
                        Map.of("inline_data", Map.of("mime_type", tipoMime,
                                "data", Base64.getEncoder().encodeToString(imagen))),
                        Map.of("text", pedido)))),
                "generationConfig", configuracion);
        // Los modelos libres en orden; el ultimo de la lista (flash-lite) siempre entra en los intentos.
        List<String> modelos = new ArrayList<>();
        modelos.add(modelo);
        modelosRespaldo().stream().filter(m -> !modelos.contains(m)).forEach(modelos::add);
        Instant ahora = Instant.now();
        List<String> libres = new ArrayList<>(modelos.stream()
                .filter(m -> ocupados.getOrDefault(m, Instant.MIN).isBefore(ahora)).toList());
        if (libres.size() > MAXIMO_MODELOS) {
            String ultimo = libres.get(libres.size() - 1);
            libres = new ArrayList<>(libres.subList(0, MAXIMO_MODELOS - 1));
            libres.add(ultimo);
        }
        for (String candidato : libres) {
            try {
                return generar(candidato, cuerpo);
            } catch (ModeloOcupadoException e) {
                // Saturado, sin cuota o inexistente: se prueba el siguiente Flash y este se salta un rato
                // (el que no existe para esta cuenta, medio dia).
                ocupados.put(candidato, Instant.now().plus(e.noExiste ? PAUSA_MODELO_INEXISTENTE : PAUSA_MODELO_OCUPADO));
            }
        }
        throw new GeminiNoDisponibleException("Ningun modelo Flash respondio");
    }

    /** El modelo no puede atender ahora (503, 429, 500, 404 o sin respuesta): se prueba otro. */
    private static class ModeloOcupadoException extends RuntimeException {
        final boolean noExiste;

        ModeloOcupadoException(String mensaje) {
            this(mensaje, false);
        }

        ModeloOcupadoException(String mensaje, boolean noExiste) {
            super(mensaje);
            this.noExiste = noExiste;
        }
    }

    private String generar(String nombreModelo, Map<String, Object> cuerpo) {
        Map<String, Object> respuesta;
        try {
            respuesta = cliente.post()
                    .uri("/models/{modelo}:generateContent", nombreModelo)
                    .body(cuerpo)
                    .retrieve()
                    .body(new ParameterizedTypeReference<Map<String, Object>>() {
                    });
        } catch (RestClientResponseException e) {
            int estado = e.getStatusCode().value();
            log.warn("Gemini respondio {} con el modelo {}: {}", estado, nombreModelo,
                    recortar(e.getResponseBodyAsString()));
            if (estado == 401 || estado == 403 || estado == 400) {
                // Llave rechazada o pedido invalido: otro modelo no lo arregla.
                throw new GeminiNoDisponibleException("Gemini respondio " + estado);
            }
            throw new ModeloOcupadoException("Gemini respondio " + estado, estado == 404);
        } catch (RestClientException e) {
            log.warn("Gemini no respondio con el modelo {}: {}", nombreModelo, e.getMessage());
            throw new ModeloOcupadoException("Gemini no respondio");
        }
        String texto = textoDe(respuesta);
        if (texto == null) {
            log.warn("Gemini no devolvio texto: {}", recortar(String.valueOf(respuesta)));
            throw new ModeloOcupadoException("Gemini no devolvio una lectura");
        }
        return texto;
    }

    /** Ultima parte de texto del primer candidato (sin las partes de razonamiento). */
    @SuppressWarnings("unchecked")
    private static String textoDe(Map<String, Object> respuesta) {
        if (respuesta == null || !(respuesta.get("candidates") instanceof List<?> candidatos) || candidatos.isEmpty()) {
            return null;
        }
        Object contenido = ((Map<String, Object>) candidatos.get(0)).get("content");
        if (!(contenido instanceof Map<?, ?> mapa) || !(mapa.get("parts") instanceof List<?> partes)) {
            return null;
        }
        String texto = null;
        for (Object parte : partes) {
            Map<String, Object> p = (Map<String, Object>) parte;
            if (p.get("text") instanceof String t && !Boolean.TRUE.equals(p.get("thought"))) {
                texto = t;
            }
        }
        return texto;
    }

    /**
     * Modelos a probar si el principal no responde: los Flash estables de la API de mayor a menor
     * version (sin el mas nuevo, que es el mismo del alias gemini-flash-latest) y al final
     * gemini-flash-lite-latest, mas liviano y casi siempre libre. La lista se arma una sola vez.
     */
    @SuppressWarnings("unchecked")
    private List<String> modelosRespaldo() {
        if (modelosRespaldo != null) {
            return modelosRespaldo;
        }
        List<String> respaldo = new ArrayList<>();
        try {
            Map<String, Object> lista = cliente.get().uri("/models?pageSize=1000").retrieve()
                    .body(new ParameterizedTypeReference<Map<String, Object>>() {
                    });
            List<String[]> flash = new ArrayList<>();
            for (Object m : (List<Object>) lista.getOrDefault("models", List.of())) {
                Matcher coincide = FLASH_ESTABLE.matcher(String.valueOf(((Map<String, Object>) m).get("name")));
                if (coincide.matches()) {
                    flash.add(new String[] { coincide.group(1), coincide.group(2),
                            coincide.group(3) == null ? "0" : coincide.group(3) });
                }
            }
            flash.sort(Comparator.<String[]>comparingInt(f -> Integer.parseInt(f[1]))
                    .thenComparingInt(f -> Integer.parseInt(f[2])).reversed());
            flash.stream().skip(modelo.endsWith("-latest") ? 1 : 0).map(f -> f[0]).forEach(respaldo::add);
        } catch (RestClientException | ClassCastException e) {
            log.warn("Gemini: no se pudo listar los modelos: {}", e.getMessage());
            respaldo.add("gemini-flash-lite-latest");
            return respaldo;
        }
        respaldo.add("gemini-flash-lite-latest");
        modelosRespaldo = List.copyOf(respaldo);
        return modelosRespaldo;
    }

    private static String recortar(String texto) {
        return texto == null ? "" : texto.length() > 300 ? texto.substring(0, 300) : texto;
    }
}
