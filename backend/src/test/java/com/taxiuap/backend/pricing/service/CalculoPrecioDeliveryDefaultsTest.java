package com.taxiuap.backend.pricing.service;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.context.support.PropertySourcesPlaceholderConfigurer;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

import com.taxiuap.backend.pricing.dto.RutaResponse;

class CalculoPrecioDeliveryDefaultsTest {

    @Test
    void usaPorDefectoLasTarifasBaseDeMoto() {
        try (AnnotationConfigApplicationContext contexto = new AnnotationConfigApplicationContext(Configuracion.class)) {
            CalculoPrecioDeliveryService calculador = contexto.getBean(CalculoPrecioDeliveryService.class);
            GeometryFactory geometria = new GeometryFactory();

            var resultado = calculador.calcularEncomienda(
                    geometria.createPoint(new Coordinate(1, 2)),
                    geometria.createPoint(new Coordinate(3, 4)));

            assertEquals(new BigDecimal("6.00"), resultado.precioServicio());
        }
    }

    @Configuration(proxyBeanMethods = false)
    @Import(CalculoPrecioDeliveryService.class)
    static class Configuracion {

        @Bean
        static PropertySourcesPlaceholderConfigurer placeholders() {
            return new PropertySourcesPlaceholderConfigurer();
        }

        @Bean
        ClienteRutas clienteRutas() {
            return (origen, destino) -> new RutaResponse(new BigDecimal("1000"), 60);
        }
    }
}
