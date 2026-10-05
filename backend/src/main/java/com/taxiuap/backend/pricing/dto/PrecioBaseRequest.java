package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;

/** Precio base del viaje: lo que cuesta hasta kmBase. */
public record PrecioBaseRequest(
        @NotNull @DecimalMin(value = "0.50", message = "El precio base debe ser de al menos 0.50 Bs")
        @Digits(integer = 6, fraction = 2) BigDecimal precioBase,
        @NotNull @DecimalMin(value = "0.1", message = "Los km del precio base deben ser al menos 0.1")
        @Digits(integer = 4, fraction = 2) BigDecimal kmBase) {
}
