package com.taxiuap.backend.pricing.service;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.math.BigDecimal;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.context.support.PropertySourcesPlaceholderConfigurer;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

import com.taxiuap.backend.pricing.dto.RutaResponse;
import com.taxiuap.backend.sistema.repository.ConfiguracionSistemaRepository;

class CalculoPrecioDeliveryDefaultsTest {

    @Test
    void usaPorDefectoLasTarifasBaseDeMoto() {
        try (AnnotationConfigApplicationContext contexto = new AnnotationConfigApplicationContext(Configuracion.class)) {
            CalculoPrecioDeliveryService calculador = contexto.getBean(CalculoPrecioDeliveryService.class);
            GeometryFactory geometria = new GeometryFactory();

            var resultado = calculador.calcularEncomienda(
                    geometria.createPoint(new Coordinate(1, 2)),
                    geometria.createPoint(new Coordinate(3, 4)));

            assertEquals(new BigDecimal("10.00"), resultado.precioServicio());
        }
    }

    @Configuration(proxyBeanMethods = false)
    @Import({CalculoPrecioDeliveryService.class, TarifaDeliveryService.class})
    static class Configuracion {

        @Bean
        static PropertySourcesPlaceholderConfigurer placeholders() {
            return new PropertySourcesPlaceholderConfigurer();
        }

        @Bean
        ConfiguracionSistemaRepository configuracionSistemaRepository() {
            // Sin nada guardado en el panel: vale la tarifa inicial (8 Bs + 2 Bs por km).
            ConfiguracionSistemaRepository repositorio = Mockito.mock(ConfiguracionSistemaRepository.class);
            Mockito.when(repositorio.findByClave(Mockito.any())).thenReturn(Optional.empty());
            return repositorio;
        }

        @Bean
        ClienteRutas clienteRutas() {
            return (origen, destino) -> new RutaResponse(new BigDecimal("1000"), 60);
        }
    }
}
