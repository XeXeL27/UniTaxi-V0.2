package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

/** Datos de entrada para crear o actualizar una tarifa. */
public record TarifaRequest(
        @NotNull Integer idCategoriaServicio,
        @NotNull Integer idZona,
        @NotNull @PositiveOrZero BigDecimal tarifaBase,
        @NotNull @PositiveOrZero BigDecimal precioKm,
        @NotNull @PositiveOrZero BigDecimal precioMinuto,
        @NotNull @PositiveOrZero BigDecimal tarifaMinima,
        @NotNull LocalDate vigenteDesde,
        LocalDate vigenteHasta) {
}
