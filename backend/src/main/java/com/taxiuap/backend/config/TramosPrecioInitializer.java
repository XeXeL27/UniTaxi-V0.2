package com.taxiuap.backend.config;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import com.taxiuap.backend.pricing.service.ParametrosPrecioService;

import lombok.RequiredArgsConstructor;

/**
 * La primera vez (tramo_precio vacia) crea los dos tramos iniciales del precio del viaje, iguales al
 * tramo del modelo anterior (+3 km +2 Bs), para que el precio no cambie. Despues los maneja el
 * administrador en Tarifas > Precio del viaje. Despues crea las tablas iniciales del paquete y del
 * delivery a partir de su tarifa de antes (base + precio por km), una sola vez.
 */
@Component
@Order(5)
@RequiredArgsConstructor
public class TramosPrecioInitializer implements ApplicationRunner {

    private final ParametrosPrecioService parametrosPrecioService;

    @Override
    public void run(ApplicationArguments args) {
        parametrosPrecioService.crearTramosIniciales();
        parametrosPrecioService.crearTablasDeEnvioIniciales();
    }
}
