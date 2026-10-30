package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import com.taxiuap.backend.trip.entity.PropuestaCostoEntrega;
import com.taxiuap.backend.trip.enums.SituacionPropuestaCosto;

import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

/**
 * Costo total presentado al cliente en una version: servicio, productos, total, el detalle tal como se
 * presento y si el cliente lo acepto (y cuando).
 */
public record PropuestaCostoResponse(
        Integer version,
        SituacionPropuestaCosto situacion,
        BigDecimal precioServicio,
        BigDecimal totalProductos,
        BigDecimal total,
        List<LineaCosto> detalle,
        LocalDateTime fechaPropuesta,
        LocalDateTime fechaRespuesta) {

    private static final JsonMapper JSON = JsonMapper.builder().build();

    /** Un producto tal como se presento al cliente. Los no conseguidos van con subtotal 0. */
    public record LineaCosto(String nombre, Integer cantidad, BigDecimal precioUnitario, BigDecimal subtotal,
            boolean conseguido, String observacion) {
    }

    public static PropuestaCostoResponse de(PropuestaCostoEntrega p) {
        return new PropuestaCostoResponse(p.getVersion(), p.getSituacionPropuesta(), p.getPrecioServicio(),
                p.getTotalProductos(), p.getTotal(), desdeJson(p.getDetalleJson()), p.getFechaPropuesta(),
                p.getFechaRespuesta());
    }

    public static String aJson(List<LineaCosto> lineas) {
        return JSON.writeValueAsString(lineas);
    }

    static List<LineaCosto> desdeJson(String json) {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        return JSON.readValue(json, new TypeReference<List<LineaCosto>>() { });
    }
}
