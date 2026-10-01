package com.taxiuap.backend.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import lombok.RequiredArgsConstructor;

/**
 * Pasa a mayusculas los nombres y apellidos guardados antes de que Persona los guardara asi (por
 * ejemplo los que vinieron de la cuenta de Google con minusculas). Solo toca las filas que tienen
 * alguna minuscula; despues de la primera vez no cambia nada.
 *
 * Corre despues de DataSeeder (@Order), aunque el seed ya los crea en mayusculas.
 */
@Component
@Order(5)
@RequiredArgsConstructor
public class NombresMayusculasInitializer implements ApplicationRunner {

    private static final Logger LOG = LoggerFactory.getLogger(NombresMayusculasInitializer.class);

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(ApplicationArguments args) {
        int filas = jdbcTemplate.update("""
                UPDATE persona SET nombres = UPPER(nombres), apellidos = UPPER(apellidos)
                WHERE nombres <> UPPER(nombres) OR apellidos <> UPPER(apellidos)""");
        if (filas > 0) LOG.info("Nombres pasados a mayusculas: {} personas", filas);
    }
}
