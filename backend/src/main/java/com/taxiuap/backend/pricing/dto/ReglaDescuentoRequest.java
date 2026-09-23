package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

/** Datos de entrada para crear o actualizar una regla de descuento estudiantil. */
public record ReglaDescuentoRequest(
        @NotNull Integer idTipoInstitucion,
        @NotNull Integer idTipoVehiculo,
        @NotNull @DecimalMin("0.00") @DecimalMax("100.00") BigDecimal porcentaje,
        @NotNull @PositiveOrZero BigDecimal montoMaximo,
        @NotNull @Positive Integer viajesMaximosDia,
        @NotNull LocalDate vigenteDesde,
        LocalDate vigenteHasta) {
}
