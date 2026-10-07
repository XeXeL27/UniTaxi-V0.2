package com.taxiuap.backend.shared.ia;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import tools.jackson.databind.json.JsonMapper;

/** Claude primero y Gemini de respaldo, con los dos servicios falsos en un servidor HTTP local. */
class LectorIaTest {

    private HttpServer servidor;
    private String url;
    private final AtomicInteger estadoClaude = new AtomicInteger(200);
    private final AtomicInteger llamadasClaude = new AtomicInteger();
    private final AtomicInteger llamadasGemini = new AtomicInteger();
    private final AtomicReference<String> pedidoClaude = new AtomicReference<>();

    @BeforeEach
    void iniciar() throws IOException {
        servidor = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        servidor.createContext("/v1/messages", intercambio -> {
            llamadasClaude.incrementAndGet();
            pedidoClaude.set(new String(intercambio.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            String cuerpo = estadoClaude.get() == 200
                    ? """
                    {"id":"msg_1","type":"message","role":"assistant","model":"claude-haiku-4-5",
                     "content":[{"type":"text","text":"{\\"origen\\":\\"claude\\"}"}],
                     "stop_reason":"end_turn","stop_sequence":null,
                     "usage":{"input_tokens":10,"output_tokens":5}}"""
                    : "{\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\",\"message\":\"Overloaded\"}}";
            responder(intercambio, estadoClaude.get(), cuerpo);
        });
        servidor.createContext("/gemini", intercambio -> {
            if ("GET".equals(intercambio.getRequestMethod())) {
                responder(intercambio, 200, "{\"models\":[]}");
                return;
            }
            llamadasGemini.incrementAndGet();
            responder(intercambio, 200,
                    "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"{\\\"origen\\\":\\\"gemini\\\"}\"}]}}]}");
        });
        servidor.start();
        url = "http://127.0.0.1:" + servidor.getAddress().getPort();
    }

    private static void responder(HttpExchange intercambio, int estado, String cuerpo) throws IOException {
        byte[] bytes = cuerpo.getBytes(StandardCharsets.UTF_8);
        intercambio.getResponseHeaders().add("Content-Type", "application/json");
        intercambio.sendResponseHeaders(estado, bytes.length);
        try (OutputStream salida = intercambio.getResponseBody()) {
            salida.write(bytes);
        }
    }

    @AfterEach
    void detener() {
        servidor.stop(0);
    }

    private LectorIa lector(String llaveClaude) {
        return new LectorIa(new ClienteClaude(llaveClaude, "claude-haiku-4-5", url, 5),
                new ClienteGemini("llave", "gemini-flash-latest", url + "/gemini", "", 5));
    }

    private static Map<String, Object> esquema() {
        Map<String, Object> propiedades = new LinkedHashMap<>();
        propiedades.put("origen", Map.of("type", "STRING"));
        propiedades.put("numero", Map.of("type", "STRING", "nullable", true));
        Map<String, Object> raiz = new LinkedHashMap<>();
        raiz.put("type", "OBJECT");
        raiz.put("properties", propiedades);
        raiz.put("required", List.of("origen"));
        raiz.put("propertyOrdering", List.of("origen", "numero"));
        return raiz;
    }

    @Test
    void leePrimeroConClaudeConElModeloHaikuYSalidaEstructurada() {
        String texto = lector("llave-claude").leerImagen("instrucciones", "Lee", new byte[] {1, 2}, "image/jpeg", esquema());
        assertEquals("{\"origen\":\"claude\"}", texto);
        assertEquals(1, llamadasClaude.get());
        assertEquals(0, llamadasGemini.get());
        Map<?, ?> pedido = JsonMapper.builder().build().readValue(pedidoClaude.get(), Map.class);
        assertEquals("claude-haiku-4-5", pedido.get("model"));
        Map<?, ?> formato = (Map<?, ?>) ((Map<?, ?>) pedido.get("output_config")).get("format");
        assertEquals("json_schema", formato.get("type"));
        assertTrue(pedidoClaude.get().contains("\"image\""));
    }

    @Test
    void siClaudeNoRespondeLeeConGemini() {
        estadoClaude.set(529);
        String texto = lector("llave-claude").leerImagen("instrucciones", "Lee", new byte[] {1, 2}, "image/jpeg", esquema());
        assertEquals("{\"origen\":\"gemini\"}", texto);
        assertTrue(llamadasClaude.get() >= 1);
        assertEquals(1, llamadasGemini.get());
    }

    @Test
    void sinLlaveDeClaudeVaDirectoAGemini() {
        String texto = lector("").leerImagen("instrucciones", "Lee", new byte[] {1, 2}, "image/jpeg", esquema());
        assertEquals("{\"origen\":\"gemini\"}", texto);
        assertEquals(0, llamadasClaude.get());
    }

    @Test
    void elEsquemaDeGeminiPasaAJsonSchema() {
        Map<String, Object> json = ClienteClaude.esquemaJson(esquema());
        assertEquals("object", json.get("type"));
        assertEquals(false, json.get("additionalProperties"));
        assertEquals(List.of("origen", "numero"), json.get("required"));
        Map<?, ?> propiedades = (Map<?, ?>) json.get("properties");
        assertEquals("string", ((Map<?, ?>) propiedades.get("origen")).get("type"));
        assertEquals(List.of("string", "null"), ((Map<?, ?>) propiedades.get("numero")).get("type"));
        assertTrue(!json.containsKey("propertyOrdering"));
    }
}
