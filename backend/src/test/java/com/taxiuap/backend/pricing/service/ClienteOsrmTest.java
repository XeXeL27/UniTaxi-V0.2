package com.taxiuap.backend.pricing.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;
import java.net.InetSocketAddress;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Coordinate;

import com.sun.net.httpserver.HttpServer;
import com.taxiuap.backend.shared.exception.NegocioException;

import tools.jackson.databind.json.JsonMapper;

class ClienteOsrmTest {

    private HttpServer servidor;
    private String cuerpoRespuesta;

    @BeforeEach
    void iniciarServidor() throws Exception {
        cuerpoRespuesta = "{\"code\":\"Ok\",\"routes\":[{\"distance\":1234.5,\"duration\":95}]}";
        servidor = HttpServer.create(new InetSocketAddress(0), 0);
        servidor.createContext("/route/v1/driving/", intercambio -> {
            byte[] respuesta = cuerpoRespuesta.getBytes();
            intercambio.sendResponseHeaders(200, respuesta.length);
            intercambio.getResponseBody().write(respuesta);
            intercambio.close();
        });
        servidor.start();
    }

    @AfterEach
    void detenerServidor() {
        servidor.stop(0);
    }

    @Test
    void interpretaDistanciaYDuracionTipadas() {
        ClienteOsrm cliente = new ClienteOsrm(JsonMapper.builder().build(),
                "http://localhost:" + servidor.getAddress().getPort(), 1000);

        var ruta = cliente.calcular(punto(1, 2), punto(3, 4));

        assertEquals(new BigDecimal("1234.5"), ruta.distanciaMetros());
        assertEquals(95, ruta.duracionSegundos());
    }

    @Test
    void rechazaDistanciaNegativaDeOsrm() {
        cuerpoRespuesta = "{\"code\":\"Ok\",\"routes\":[{\"distance\":-1,\"duration\":95}]}";
        ClienteOsrm cliente = new ClienteOsrm(JsonMapper.builder().build(),
                "http://localhost:" + servidor.getAddress().getPort(), 1000);

        assertThrows(NegocioException.class, () -> cliente.calcular(punto(1, 2), punto(3, 4)));
    }

    @Test
    void rechazaDuracionNegativaDeOsrm() {
        cuerpoRespuesta = "{\"code\":\"Ok\",\"routes\":[{\"distance\":1234.5,\"duration\":-1}]}";
        ClienteOsrm cliente = new ClienteOsrm(JsonMapper.builder().build(),
                "http://localhost:" + servidor.getAddress().getPort(), 1000);

        assertThrows(NegocioException.class, () -> cliente.calcular(punto(1, 2), punto(3, 4)));
    }

    private Point punto(double x, double y) {
        return new GeometryFactory().createPoint(new Coordinate(x, y));
    }
}
