package com.taxiuap.backend.pricing.service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

import org.locationtech.jts.geom.Point;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import com.taxiuap.backend.pricing.dto.RutaResponse;
import com.taxiuap.backend.shared.exception.NegocioException;

/** Cliente OSRM para rutas de vehiculos, sin respaldo en linea recta. */
@Service
public class ClienteOsrm implements ClienteRutas {

    private final JsonMapper objectMapper;

    private final String servidor;
    private final long timeoutMilisegundos;

    public ClienteOsrm(JsonMapper objectMapper,
            @Value("${taxiuap.rutas.osrm.url:https://router.project-osrm.org}") String servidor,
            @Value("${taxiuap.rutas.osrm.timeout-ms:5000}") long timeoutMilisegundos) {
        this.objectMapper = objectMapper;
        this.servidor = servidor;
        this.timeoutMilisegundos = timeoutMilisegundos;
    }

    @Override
    public RutaResponse calcular(Point origen, Point destino) {
        String coordenadas = origen.getX() + "," + origen.getY() + ";" + destino.getX() + "," + destino.getY();
        URI uri = URI.create(servidor + "/route/v1/driving/" + coordenadas + "?overview=false");
        HttpRequest request = HttpRequest.newBuilder(uri)
                .timeout(Duration.ofMillis(timeoutMilisegundos))
                .header("Accept", "application/json")
                .GET()
                .build();
        try {
            HttpResponse<String> response = HttpClient.newHttpClient().send(request,
                    HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new NegocioException("OSRM no pudo calcular la ruta");
            }
            return interpretar(response.body());
        } catch (NegocioException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new NegocioException("OSRM no esta disponible");
        }
    }

    private RutaResponse interpretar(String cuerpo) throws Exception {
        JsonNode raiz = objectMapper.readTree(cuerpo);
        if (!"Ok".equals(raiz.path("code").asText())) {
            throw new NegocioException("OSRM no encontro una ruta");
        }
        JsonNode ruta = raiz.path("routes").path(0);
        if (ruta.isMissingNode() || !ruta.has("distance") || !ruta.has("duration")) {
            throw new NegocioException("La respuesta de OSRM no contiene una ruta valida");
        }
        return new RutaResponse(ruta.get("distance").decimalValue(), ruta.get("duration").asInt());
    }
}
