package com.taxiuap.backend.shared.ia;

import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Lectura de imagenes con IA: primero Claude (ClienteClaude, Sonnet 5.5) y, si no responde o no tiene
 * llave, Gemini (ClienteGemini, con su propia cadena de modelos de respaldo). Los dos reciben las mismas
 * instrucciones y el mismo esquema y devuelven el mismo JSON.
 */
@Component
public class LectorIa {

    private static final Logger log = LoggerFactory.getLogger(LectorIa.class);

    private final ClienteClaude claude;
    private final ClienteGemini gemini;

    public LectorIa(ClienteClaude claude, ClienteGemini gemini) {
        this.claude = claude;
        this.gemini = gemini;
    }

    /** Hay al menos un lector con llave. */
    public boolean configurado() {
        return claude.configurado() || gemini.configurado();
    }

    public String leerImagen(String instrucciones, String pedido, byte[] imagen, String tipoMime,
            Map<String, Object> esquema) {
        return leerImagenes(instrucciones, pedido, List.of(new ImagenIa(imagen, tipoMime)), esquema);
    }

    /**
     * Devuelve el texto JSON que sigue [esquema].
     *
     * @throws IaNoDisponibleException si ni Claude ni Gemini pudieron leer
     */
    public String leerImagenes(String instrucciones, String pedido, List<ImagenIa> imagenes,
            Map<String, Object> esquema) {
        if (claude.configurado()) {
            try {
                return claude.leerImagenes(instrucciones, pedido, imagenes, esquema);
            } catch (IaNoDisponibleException e) {
                if (!gemini.configurado()) {
                    throw e;
                }
                log.info("Claude no pudo leer ({}): se lee con Gemini", e.getMessage());
            }
        }
        if (!gemini.configurado()) {
            throw new IaNoDisponibleException("Faltan ANTHROPIC_API_KEY y GEMINI_API_KEY");
        }
        return gemini.leerImagenes(instrucciones, pedido, imagenes, esquema);
    }
}
