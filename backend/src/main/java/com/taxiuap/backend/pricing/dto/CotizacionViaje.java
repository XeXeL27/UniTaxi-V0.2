package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;

import com.taxiuap.backend.institution.entity.Estudiante;

/**
 * Precio de un viaje antes de pedirlo: distancia por calles, precio normal (ParametrosPrecio), el
 * descuento de estudiante si corresponde y lo que se paga. estudiante solo viene cuando hubo descuento.
 */
public record CotizacionViaje(
        BigDecimal distanciaKm,
        int duracionMin,
        boolean porCalles,
        BigDecimal precioNormal,
        BigDecimal descuentoEstudiante,
        BigDecimal precioFinal,
        Estudiante estudiante) {
}
