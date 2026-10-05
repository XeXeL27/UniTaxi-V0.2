package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;

/** Km y costo que un tramo suma a los anteriores. */
public record TramoPrecioRequest(
        @NotNull @DecimalMin(value = "0.1", message = "El tramo debe ser de al menos 0.1 km")
        @Digits(integer = 4, fraction = 2) BigDecimal kmAdicional,
        @NotNull @DecimalMin(value = "0.0", message = "El costo del tramo no puede ser negativo")
        @Digits(integer = 6, fraction = 2) BigDecimal costoAdicional) {
}
