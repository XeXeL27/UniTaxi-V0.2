package com.taxiuap.backend.location.dto;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

/** Posicion que manda la app del pasajero mientras esta abierta en pantalla. */
public record LatidoPasajeroRequest(
        @NotNull(message = "Falta la latitud")
        @DecimalMin(value = "-90", message = "La latitud debe estar entre -90 y 90")
        @DecimalMax(value = "90", message = "La latitud debe estar entre -90 y 90")
        BigDecimal latitud,
        @NotNull(message = "Falta la longitud")
        @DecimalMin(value = "-180", message = "La longitud debe estar entre -180 y 180")
        @DecimalMax(value = "180", message = "La longitud debe estar entre -180 y 180")
        BigDecimal longitud) {
}
