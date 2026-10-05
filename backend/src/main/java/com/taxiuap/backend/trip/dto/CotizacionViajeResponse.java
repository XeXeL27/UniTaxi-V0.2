package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

/**
 * Precio que ve el pasajero al elegir destino, antes de pedir: km por calles (porCalles false: linea
 * recta porque OSRM no respondio), precio normal, su descuento de estudiante y lo que paga.
 */
public record CotizacionViajeResponse(
        BigDecimal distanciaKm,
        int duracionMin,
        boolean porCalles,
        BigDecimal precioNormal,
        BigDecimal descuentoEstudiante,
        BigDecimal precio,
        String moneda) {
}
