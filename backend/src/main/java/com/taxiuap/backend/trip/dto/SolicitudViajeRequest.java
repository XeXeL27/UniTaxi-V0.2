package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

/** Datos para que un pasajero solicite un viaje. Origen y destino viajan como WKT POINT. */
public record SolicitudViajeRequest(
        @NotNull Integer idCategoriaServicio,
        @NotBlank String origenWkt,
        @NotBlank String destinoWkt,
        String origenDireccion,
        String destinoDireccion,
        @PositiveOrZero BigDecimal precioSugerido) {
}
