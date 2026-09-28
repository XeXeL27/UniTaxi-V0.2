package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;

/**
 * Datos para que un pasajero solicite un viaje. Origen y destino viajan como WKT POINT. Sin
 * categoria de servicio se usa la categoria ESTANDAR (taxi comun).
 */
public record SolicitudViajeRequest(
        Integer idCategoriaServicio,
        @NotBlank String origenWkt,
        @NotBlank String destinoWkt,
        String origenDireccion,
        String destinoDireccion,
        @PositiveOrZero BigDecimal precioSugerido) {
}
