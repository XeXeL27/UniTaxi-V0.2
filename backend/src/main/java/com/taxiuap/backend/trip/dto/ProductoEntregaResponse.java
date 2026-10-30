package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

import com.taxiuap.backend.trip.entity.ProductoEntrega;
import com.taxiuap.backend.trip.enums.SituacionProducto;

/** Producto de una compra: lo que pidio el cliente y, despues de comprar, lo que registro el repartidor. */
public record ProductoEntregaResponse(
        Long id,
        Integer orden,
        String nombre,
        Integer cantidad,
        String indicaciones,
        SituacionProducto situacion,
        Integer cantidadConseguida,
        BigDecimal precioUnitario,
        BigDecimal subtotal,
        String observacion) {

    public static ProductoEntregaResponse de(ProductoEntrega p) {
        return new ProductoEntregaResponse(p.getId(), p.getOrden(), p.getNombre(), p.getCantidad(),
                p.getIndicaciones(), p.getSituacionProducto(), p.getCantidadConseguida(), p.getPrecioUnitario(),
                p.getSubtotal(), p.getObservacion());
    }
}
