package com.taxiuap.backend.config;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import com.taxiuap.backend.trip.dto.PropuestaCostoResponse;

/**
 * Compras en curso pedidas antes de la lista de productos (cuando el cliente confirmaba la compra antes
 * de que el repartidor comprara). La app nueva necesita los productos y el costo total aceptado, asi
 * que al arrancar se completan una sola vez:
 * <ul>
 * <li>Sin comprar todavia: un producto con la descripcion del pedido (cantidad 1) y se quita la
 * confirmacion previa; el cliente acepta el costo total despues de la compra, como en un pedido nuevo.</li>
 * <li>Ya comprada (en manos del repartidor): el producto con lo que costo y la version 1 del costo total
 * ya ACEPTADA por el cliente, que ya la habia confirmado.</li>
 * </ul>
 * Solo toca compras sin productos de viajes o solicitudes sin terminar; despues no cambia nada.
 */
@Component
@Order(6)
public class ComprasAnterioresInitializer implements ApplicationRunner {

    private static final Logger LOG = LoggerFactory.getLogger(ComprasAnterioresInitializer.class);

    private final JdbcTemplate jdbcTemplate;
    private final TransactionTemplate transaccion;

    public ComprasAnterioresInitializer(JdbcTemplate jdbcTemplate, PlatformTransactionManager transacciones) {
        this.jdbcTemplate = jdbcTemplate;
        this.transaccion = new TransactionTemplate(transacciones);
    }

    @Override
    public void run(ApplicationArguments args) {
        List<Map<String, Object>> compras = jdbcTemplate.queryForList("""
                SELECT d.id_datos_entrega, d.descripcion, d.estado_entrega, d.costo_producto_real,
                       v.id_viaje, v.id_conductor, v.precio_final, p.id_usuario
                  FROM datos_entrega d
                  JOIN solicitud_viaje s ON s.id_sol_viaje = d.id_sol_viaje
                  LEFT JOIN viaje v ON v.id_sol_viaje = d.id_sol_viaje
                  LEFT JOIN pasajero p ON p.id_pasajero = v.id_pasajero
                 WHERE d.tipo_envio = 'COMPRA_Y_ENTREGA'
                   AND d.estado_entrega IN ('PENDIENTE_RECOGIDA', 'EN_CAMINO_RECOGIDA', 'EN_MANO')
                   AND s.situacion_solicitud IN ('PENDIENTE', 'CON_OFERTAS', 'ACEPTADA')
                   AND (v.id_viaje IS NULL OR v.situacion_viaje NOT IN ('COMPLETADO', 'CANCELADO'))
                   AND NOT EXISTS (SELECT 1 FROM producto_entrega pe WHERE pe.id_datos_entrega = d.id_datos_entrega)
                """);
        int completadas = 0;
        for (Map<String, Object> compra : compras) {
            try {
                transaccion.executeWithoutResult(estado -> completar(compra));
                completadas++;
            } catch (RuntimeException e) {
                LOG.warn("No se pudo completar la compra anterior {}: {}", compra.get("id_datos_entrega"),
                        e.getMessage());
            }
        }
        if (completadas > 0) LOG.info("Compras en curso de antes de la lista de productos completadas: {}", completadas);
    }

    private void completar(Map<String, Object> compra) {
        Long idDatos = ((Number) compra.get("id_datos_entrega")).longValue();
        String nombre = recortar(String.valueOf(compra.get("descripcion")).trim().replaceAll("\\s+", " "));
        LocalDateTime ahora = LocalDateTime.now();
        BigDecimal costoReal = (BigDecimal) compra.get("costo_producto_real");
        BigDecimal servicio = (BigDecimal) compra.get("precio_final");

        if (!"EN_MANO".equals(compra.get("estado_entrega"))) {
            jdbcTemplate.update("""
                    INSERT INTO producto_entrega (id_datos_entrega, orden, nombre, cantidad, situacion_producto,
                           estado_producto_entrega, creado_en)
                    VALUES (?, 1, ?, 1, 'PENDIENTE', 'A', ?)""", idDatos, nombre, ahora);
            jdbcTemplate.update("""
                    UPDATE datos_entrega SET compra_confirmada_por_cliente = false, costo_producto_confirmado = null
                     WHERE id_datos_entrega = ?""", idDatos);
            LOG.info("Compra anterior {}: producto creado con la descripcion del pedido", idDatos);
            return;
        }

        // Ya comprada: sin costo, viaje o precio del servicio no hay total que presentar (queda como estaba).
        if (costoReal == null || servicio == null || compra.get("id_viaje") == null) {
            throw new IllegalStateException("compra en mano sin costo real o sin precio del servicio");
        }
        BigDecimal producto = costoReal.setScale(2, RoundingMode.HALF_UP);
        BigDecimal envio = servicio.setScale(2, RoundingMode.HALF_UP);
        jdbcTemplate.update("""
                INSERT INTO producto_entrega (id_datos_entrega, orden, nombre, cantidad, situacion_producto,
                       cantidad_conseguida, precio_unitario, subtotal, estado_producto_entrega, creado_en)
                VALUES (?, 1, ?, 1, 'CONSEGUIDO', 1, ?, ?, 'A', ?)""", idDatos, nombre, producto, producto, ahora);
        String detalle = PropuestaCostoResponse.aJson(List.of(
                new PropuestaCostoResponse.LineaCosto(nombre, 1, producto, producto, true, null)));
        jdbcTemplate.update("""
                INSERT INTO propuesta_costo_entrega (id_datos_entrega, id_viaje, id_conductor, version,
                       precio_servicio, total_productos, total, detalle_json, situacion_propuesta, fecha_propuesta,
                       fecha_respuesta, id_usuario_acepta, estado_propuesta_costo, creado_en)
                VALUES (?, ?, ?, 1, ?, ?, ?, ?, 'ACEPTADA', ?, ?, ?, 'A', ?)""",
                idDatos, compra.get("id_viaje"), compra.get("id_conductor"), envio, producto, producto.add(envio),
                detalle, ahora, ahora, compra.get("id_usuario"), ahora);
        jdbcTemplate.update("""
                UPDATE datos_entrega SET compra_confirmada_por_cliente = true, costo_producto_confirmado = ?
                 WHERE id_datos_entrega = ?""", producto, idDatos);
        LOG.info("Compra anterior {}: producto y costo total aceptado creados ({} Bs)", idDatos, producto.add(envio));
    }

    private static String recortar(String texto) {
        String limpio = texto.isBlank() ? "Pedido" : texto;
        return limpio.length() <= 150 ? limpio : limpio.substring(0, 147).trim() + "...";
    }
}
