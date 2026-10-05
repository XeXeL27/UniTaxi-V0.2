package com.taxiuap.backend.pricing.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.URI;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import org.locationtech.jts.geom.Point;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import lombok.extern.slf4j.Slf4j;

/**
 * Distancia y tiempo de un viaje por calles, con el OSRM publico (el mismo que dibuja la ruta en la
 * app). Si OSRM no responde se usa la linea recta (haversine) a 25 km/h, para no dejar al pasajero
 * sin precio.
 */
@Slf4j
@Service
public class DistanciaRutaService {

    /** Distancia del viaje; porCalles = false si salio de la linea recta. */
    public record DistanciaRuta(BigDecimal km, int minutos, boolean porCalles) {
    }

    private static final double RADIO_TIERRA_KM = 6371.0;
    private static final double VELOCIDAD_URBANA_KMH = 25.0;

    private final RestClient cliente;
    private final String servidor;

    public DistanciaRutaService(
            @Value("${taxiuap.rutas.osrm.url:https://router.project-osrm.org}") String servidor,
            @Value("${taxiuap.rutas.osrm.timeout-ms:5000}") long timeoutMs) {
        HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofMillis(timeoutMs)).build();
        JdkClientHttpRequestFactory fabrica = new JdkClientHttpRequestFactory(http);
        fabrica.setReadTimeout(Duration.ofMillis(timeoutMs));
        this.servidor = servidor.endsWith("/") ? servidor.substring(0, servidor.length() - 1) : servidor;
        this.cliente = RestClient.builder()
                .requestFactory(fabrica)
                // Sin comprimir: el cliente JDK de Spring no descomprime el "deflate" de OSRM (ZipException).
                .defaultHeader("Accept-Encoding", "identity")
                .build();
    }

    public DistanciaRuta medir(Point origen, Point destino) {
        try {
            String coordenadas = String.format(Locale.ROOT, "%.6f,%.6f;%.6f,%.6f",
                    origen.getX(), origen.getY(), destino.getX(), destino.getY());
            Map<?, ?> respuesta = cliente.get()
                    // URI armada a mano: ";" y "," deben llegar sin codificar.
                    .uri(URI.create(servidor + "/route/v1/driving/" + coordenadas + "?overview=false"))
                    .retrieve()
                    .body(Map.class);
            if (respuesta != null && "Ok".equals(respuesta.get("code"))
                    && respuesta.get("routes") instanceof List<?> rutas && !rutas.isEmpty()
                    && rutas.get(0) instanceof Map<?, ?> ruta
                    && ruta.get("distance") instanceof Number metros
                    && ruta.get("duration") instanceof Number segundos
                    && metros.doubleValue() >= 0 && Double.isFinite(metros.doubleValue())) {
                return new DistanciaRuta(km(metros.doubleValue() / 1000.0),
                        (int) Math.max(1, Math.ceil(segundos.doubleValue() / 60.0)), true);
            }
            log.warn("OSRM no devolvio una ruta; se usa la linea recta");
        } catch (RestClientException e) {
            log.warn("OSRM no respondio ({}); se usa la linea recta", causa(e));
        }
        return lineaRecta(origen, destino);
    }

    /** Distancia en linea recta (haversine) a velocidad urbana constante. */
    public static DistanciaRuta lineaRecta(Point origen, Point destino) {
        double lat1 = Math.toRadians(origen.getY());
        double lat2 = Math.toRadians(destino.getY());
        double deltaLat = Math.toRadians(destino.getY() - origen.getY());
        double deltaLon = Math.toRadians(destino.getX() - origen.getX());
        double a = Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2)
                + Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLon / 2) * Math.sin(deltaLon / 2);
        double kilometros = RADIO_TIERRA_KM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        int minutos = (int) Math.max(1, Math.round(kilometros / VELOCIDAD_URBANA_KMH * 60));
        return new DistanciaRuta(km(kilometros), minutos, false);
    }

    private static String causa(Throwable e) {
        Throwable raiz = e;
        while (raiz.getCause() != null && raiz.getCause() != raiz) raiz = raiz.getCause();
        return raiz == e ? e.getMessage() : e.getMessage() + " / " + raiz;
    }

    private static BigDecimal km(double kilometros) {
        return BigDecimal.valueOf(kilometros).setScale(2, RoundingMode.HALF_UP);
    }
}
