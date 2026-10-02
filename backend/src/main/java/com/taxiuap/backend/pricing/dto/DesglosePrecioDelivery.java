package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;

/** Precio del servicio DELIVERY y su desglose de cobro. */
public record DesglosePrecioDelivery(
        BigDecimal precioServicio,
        BigDecimal distanciaKm,
        Integer duracionMinutos,
        boolean estimado,
        BigDecimal costoProducto,
        BigDecimal totalCliente,
        BigDecimal comision,
        BigDecimal gananciaPlataforma,
        BigDecimal gananciaRepartidor) {

    public DesglosePrecioDelivery(BigDecimal precioServicio, BigDecimal distanciaKm,
            Integer duracionMinutos, boolean estimado) {
        this(precioServicio, distanciaKm, duracionMinutos, estimado, BigDecimal.ZERO,
                precioServicio, BigDecimal.ZERO, BigDecimal.ZERO, precioServicio);
    }
}
