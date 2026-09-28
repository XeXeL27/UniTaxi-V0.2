package com.taxiuap.backend.config;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import com.taxiuap.backend.rating.service.CalificacionService;

import lombok.RequiredArgsConstructor;

/**
 * Deja el promedio y el total de calificaciones de cada conductor iguales a sus calificaciones
 * activas. Corrige los datos cargados sin pasar por el servicio (por ejemplo el seed); despues de
 * eso cada calificacion nueva o eliminada ya lo mantiene al dia.
 *
 * Corre despues de DataSeeder (@Order), que crea calificaciones.
 */
@Component
@Order(4)
@RequiredArgsConstructor
public class CalificacionesInitializer implements ApplicationRunner {

    private final CalificacionService calificacionService;

    @Override
    public void run(ApplicationArguments args) {
        calificacionService.recalcularTodos();
    }
}
