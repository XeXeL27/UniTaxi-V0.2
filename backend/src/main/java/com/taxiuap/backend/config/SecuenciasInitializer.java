package com.taxiuap.backend.config;

import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import lombok.RequiredArgsConstructor;

/**
 * Deja cada secuencia de clave primaria en el ultimo id que existe, para que el siguiente registro sea
 * el correlativo.
 *
 * Las secuencias de PostgreSQL no retroceden solas: si se borra fisicamente un registro (por ejemplo,
 * una cuenta de prueba desde DBeaver o un script), el siguiente seguia con el id que venia despues del
 * borrado y quedaban huecos al final. Al arrancar se recorren todas las tablas con secuencia y se
 * ajustan al maximo actual (una tabla vacia vuelve a empezar en 1). Los huecos del medio no se tocan.
 *
 * Corre antes que los demas inicializadores (@Order), que ya insertan datos.
 */
@Component
@Order(-1)
@RequiredArgsConstructor
public class SecuenciasInitializer implements ApplicationRunner {

    private static final Logger LOG = LoggerFactory.getLogger(SecuenciasInitializer.class);

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(ApplicationArguments args) {
        List<Map<String, Object>> claves = jdbcTemplate.queryForList("""
                select tc.table_name as tabla, kcu.column_name as columna,
                       pg_get_serial_sequence(quote_ident(tc.table_name), kcu.column_name) as secuencia
                from information_schema.table_constraints tc
                join information_schema.key_column_usage kcu on tc.constraint_name = kcu.constraint_name
                where tc.constraint_type = 'PRIMARY KEY' and tc.table_schema = 'public'""");
        int ajustadas = 0;
        for (Map<String, Object> clave : claves) {
            String secuencia = (String) clave.get("secuencia");
            if (secuencia == null) {
                continue;
            }
            String tabla = (String) clave.get("tabla");
            String columna = (String) clave.get("columna");
            try {
                Long maximo = jdbcTemplate.queryForObject(
                        "select max(\"" + columna + "\") from \"" + tabla + "\"", Long.class);
                Long ultimo = jdbcTemplate.queryForObject("select last_value from " + secuencia, Long.class);
                if (maximo == null) {
                    jdbcTemplate.queryForObject("select setval(?, 1, false)", Long.class, secuencia);
                } else if (!maximo.equals(ultimo)) {
                    jdbcTemplate.queryForObject("select setval(?, ?, true)", Long.class, secuencia, maximo);
                    ajustadas++;
                }
            } catch (RuntimeException e) {
                // Un fallo aqui no debe impedir el arranque.
                LOG.warn("No se pudo ajustar la secuencia de {}.{}: {}", tabla, columna, e.getMessage());
            }
        }
        if (ajustadas > 0) {
            LOG.info("Secuencias ajustadas al ultimo id existente: {}", ajustadas);
        }
    }
}
