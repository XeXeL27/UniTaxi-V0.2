package com.taxiuap.backend.pricing.service;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.math.BigDecimal;
import java.net.InetSocketAddress;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Coordinate;

import com.sun.net.httpserver.HttpServer;

import tools.jackson.databind.json.JsonMapper;

class ClienteOsrmTest {

    private HttpServer servidor;

    @BeforeEach
    void iniciarServidor() throws Exception {
        servidor = HttpServer.create(new InetSocketAddress(0), 0);
        servidor.createContext("/route/v1/driving/", intercambio -> {
            byte[] respuesta = "{\"code\":\"Ok\",\"routes\":[{\"distance\":1234.5,\"duration\":95}]}".getBytes();
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

    private Point punto(double x, double y) {
        return new GeometryFactory().createPoint(new Coordinate(x, y));
    }
}
