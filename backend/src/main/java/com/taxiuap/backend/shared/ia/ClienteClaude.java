package com.taxiuap.backend.shared.ia;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.anthropic.core.JsonValue;
import com.anthropic.errors.AnthropicException;
import com.anthropic.models.messages.Base64ImageSource;
import com.anthropic.models.messages.ContentBlockParam;
import com.anthropic.models.messages.ImageBlockParam;
import com.anthropic.models.messages.JsonOutputFormat;
import com.anthropic.models.messages.Message;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.OutputConfig;
import com.anthropic.models.messages.StopReason;
import com.anthropic.models.messages.TextBlock;
import com.anthropic.models.messages.TextBlockParam;

/**
 * Cliente de la API de Claude (Anthropic) para leer imagenes y devolver JSON con un esquema fijo
 * (salida estructurada). Es el primer lector de LectorIa; si no responde se usa Gemini. La llave solo
 * vive en el servidor (ANTHROPIC_API_KEY): nunca va en la app.
 *
 * Modelo por defecto claude-sonnet-5-5: con fotos reales de carnets bolivianos claude-haiku-4-5 leia mal
 * numeros y apellidos (2026-10-07). Se cambia con CLAUDE_MODELO.
 *
 * Recibe el mismo esquema que Gemini (formato OpenAPI: tipos en mayusculas, nullable, propertyOrdering)
 * y lo pasa a JSON Schema (esquemaJson).
 */
@Component
public class ClienteClaude {

    private static final Logger log = LoggerFactory.getLogger(ClienteClaude.class);

    private final AnthropicClient cliente;
    private final String modelo;

    public ClienteClaude(
            @Value("${taxiuap.claude.api-key:${ANTHROPIC_API_KEY:}}") String apiKey,
            @Value("${taxiuap.claude.modelo:${CLAUDE_MODELO:claude-sonnet-5-5}}") String modelo,
            @Value("${taxiuap.claude.url:https://api.anthropic.com}") String url,
            @Value("${taxiuap.claude.segundos-espera:25}") int segundosEspera) {
        String llave = apiKey == null ? "" : apiKey.trim();
        this.modelo = modelo;
        this.cliente = llave.isEmpty() ? null : AnthropicOkHttpClient.builder()
                .apiKey(llave)
                .baseUrl(url)
                .timeout(Duration.ofSeconds(segundosEspera))
                // Un reintento ante 429/5xx o corte de red; despues pasa a Gemini.
                .maxRetries(1)
                .build();
        if (cliente == null) {
            log.warn("Falta ANTHROPIC_API_KEY: el carnet y la licencia se leen solo con Gemini");
        }
    }

    /** Hay una llave configurada. */
    public boolean configurado() {
        return cliente != null;
    }

    public String modelo() {
        return modelo;
    }

    /**
     * Envia las imagenes (en el orden en que las describe [pedido]) con sus instrucciones y devuelve el
     * texto JSON de la respuesta, que sigue [esquema].
     *
     * @throws IaNoDisponibleException sin llave, sin conexion, sin cuota, llave rechazada o respuesta
     *                                 incompleta (rechazo del modelo o corte por longitud)
     */
    public String leerImagenes(String instrucciones, String pedido, List<ImagenIa> imagenes,
            Map<String, Object> esquema) {
        if (cliente == null) {
            throw new IaNoDisponibleException("Falta ANTHROPIC_API_KEY");
        }
        List<ContentBlockParam> partes = new ArrayList<>();
        for (ImagenIa imagen : imagenes) {
            partes.add(ContentBlockParam.ofImage(ImageBlockParam.builder()
                    .source(Base64ImageSource.builder()
                            .data(Base64.getEncoder().encodeToString(imagen.bytes()))
                            .mediaType(Base64ImageSource.MediaType.of(tipo(imagen.tipoMime())))
                            .build())
                    .build()));
        }
        partes.add(ContentBlockParam.ofText(TextBlockParam.builder().text(pedido).build()));
        JsonOutputFormat.Schema.Builder schema = JsonOutputFormat.Schema.builder();
        esquemaJson(esquema).forEach((clave, valor) -> schema.putAdditionalProperty(clave, JsonValue.from(valor)));
        MessageCreateParams params = MessageCreateParams.builder()
                .model(modelo)
                .maxTokens(2048L)
                .system(instrucciones)
                .outputConfig(OutputConfig.builder()
                        .format(JsonOutputFormat.builder().schema(schema.build()).build())
                        .build())
                .addUserMessageOfBlockParams(partes)
                .build();
        Message respuesta;
        try {
            respuesta = cliente.messages().create(params);
        } catch (AnthropicException e) {
            log.warn("Claude no respondio con el modelo {}: {}", modelo, e.getMessage());
            throw new IaNoDisponibleException("Claude no respondio: " + e.getMessage());
        }
        StopReason fin = respuesta.stopReason().orElse(null);
        if (!StopReason.END_TURN.equals(fin)) {
            log.warn("Claude termino la lectura con {} (modelo {})", fin, modelo);
            throw new IaNoDisponibleException("Claude no completo la lectura: " + fin);
        }
        String texto = respuesta.content().stream()
                .flatMap(bloque -> bloque.text().stream())
                .map(TextBlock::text)
                .collect(Collectors.joining());
        if (texto.isBlank()) {
            throw new IaNoDisponibleException("Claude respondio sin texto");
        }
        return texto;
    }

    /** Claude acepta JPEG, PNG, GIF y WEBP; lo demas se manda como JPEG (las fotos se toman asi). */
    private static String tipo(String tipoMime) {
        return tipoMime != null && List.of("image/jpeg", "image/png", "image/gif", "image/webp").contains(tipoMime)
                ? tipoMime : "image/jpeg";
    }

    /**
     * Esquema de Gemini (OpenAPI) a JSON Schema: tipos en minuscula, nullable como ["tipo", "null"],
     * objetos sin propiedades extra y con todas sus propiedades obligatorias (las que pueden faltar
     * vienen como null). propertyOrdering no existe en JSON Schema y se quita.
     */
    @SuppressWarnings("unchecked")
    static Map<String, Object> esquemaJson(Map<String, Object> gemini) {
        Map<String, Object> json = new LinkedHashMap<>();
        String tipo = String.valueOf(gemini.get("type")).toLowerCase();
        boolean nulo = Boolean.TRUE.equals(gemini.get("nullable"));
        json.put("type", nulo ? List.of(tipo, "null") : tipo);
        if (gemini.get("enum") instanceof List<?> valores) {
            json.put("enum", valores);
        }
        if (gemini.get("properties") instanceof Map<?, ?> propiedades) {
            Map<String, Object> convertidas = new LinkedHashMap<>();
            propiedades.forEach((clave, valor) ->
                    convertidas.put((String) clave, esquemaJson((Map<String, Object>) valor)));
            json.put("properties", convertidas);
            json.put("required", List.copyOf(convertidas.keySet()));
            json.put("additionalProperties", false);
        }
        return json;
    }
}
