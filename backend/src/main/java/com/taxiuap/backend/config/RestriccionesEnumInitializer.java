package com.taxiuap.backend.config;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import jakarta.persistence.Column;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import lombok.RequiredArgsConstructor;

/**
 * Mantiene al dia las restricciones CHECK de las columnas enum.
 *
 * Hibernate crea un CHECK con los valores del enum al crear la tabla, pero con ddl-auto=update no
 * lo vuelve a tocar: si despues se agrega un valor al enum (por ejemplo FINALIZADA en
 * SituacionSolicitud), la base lo rechaza. Este inicializador recorre las entidades, compara cada
 * CHECK existente de una columna @Enumerated(STRING) con los valores del enum en Java y, si le
 * falta alguno, lo reemplaza. Nunca crea restricciones nuevas ni toca columnas que no sean enum.
 *
 * Corre antes que AdminInitializer y DataSeeder (@Order), que ya insertan datos.
 */
@Component
@Order(0)
@RequiredArgsConstructor
public class RestriccionesEnumInitializer implements ApplicationRunner {

    private static final Logger LOG = LoggerFactory.getLogger(RestriccionesEnumInitializer.class);

    private final EntityManagerFactory entityManagerFactory;
    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(ApplicationArguments args) {
        for (ColumnaEnum columna : columnasEnum()) {
            try {
                actualizar(columna);
            } catch (RuntimeException e) {
                // Un fallo aqui no debe impedir el arranque: se avisa y se sigue con las demas.
                LOG.warn("No se pudo revisar la restriccion de {}.{}: {}", columna.tabla(), columna.columna(),
                        e.getMessage());
            }
        }
    }

    private void actualizar(ColumnaEnum columna) {
        List<Map<String, Object>> restricciones = jdbcTemplate.queryForList(
                "select conname, pg_get_constraintdef(oid) as definicion from pg_constraint "
                        + "where contype = 'c' and conrelid = to_regclass(?)",
                columna.tabla());
        for (Map<String, Object> restriccion : restricciones) {
            String nombre = (String) restriccion.get("conname");
            String definicion = (String) restriccion.get("definicion");
            if (!definicion.contains("(" + columna.columna() + ")")) {
                continue;
            }
            boolean completa = columna.valores().stream().allMatch(v -> definicion.contains("'" + v + "'"));
            if (completa) {
                continue;
            }
            String lista = columna.valores().stream().map(v -> "'" + v + "'").collect(Collectors.joining(", "));
            jdbcTemplate.execute("alter table " + columna.tabla() + " drop constraint " + nombre);
            jdbcTemplate.execute("alter table " + columna.tabla() + " add constraint " + nombre
                    + " check (" + columna.columna() + " in (" + lista + "))");
            LOG.info("Restriccion {} actualizada con los valores {}", nombre, columna.valores());
        }
    }

    /** Columnas @Enumerated(STRING) de todas las entidades, con su tabla y los valores del enum. */
    private List<ColumnaEnum> columnasEnum() {
        List<ColumnaEnum> columnas = new ArrayList<>();
        entityManagerFactory.getMetamodel().getEntities().forEach(entidad -> {
            Class<?> clase = entidad.getJavaType();
            Table tabla = clase.getAnnotation(Table.class);
            if (tabla == null) {
                return;
            }
            for (Class<?> actual = clase; actual != null && actual != Object.class; actual = actual.getSuperclass()) {
                for (Field campo : actual.getDeclaredFields()) {
                    Enumerated enumerado = campo.getAnnotation(Enumerated.class);
                    Column columna = campo.getAnnotation(Column.class);
                    if (enumerado == null || enumerado.value() != EnumType.STRING || columna == null
                            || !campo.getType().isEnum()) {
                        continue;
                    }
                    List<String> valores = Arrays.stream(campo.getType().getEnumConstants())
                            .map(valor -> ((Enum<?>) valor).name())
                            .toList();
                    columnas.add(new ColumnaEnum(tabla.name(), columna.name(), valores));
                }
            }
        });
        return columnas;
    }

    private record ColumnaEnum(String tabla, String columna, List<String> valores) {
    }
}
