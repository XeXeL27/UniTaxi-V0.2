package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;

/** Tarifa del delivery que guarda el administrador en el panel (Tarifas > Tarifa del delivery). */
public record TarifaDeliveryRequest(
        @NotNull(message = "Indica la tarifa base")
        @DecimalMin(value = "0.00", message = "La tarifa base no puede ser negativa")
        @Digits(integer = 6, fraction = 2, message = "La tarifa base admite hasta 2 decimales") BigDecimal tarifaBase,
        @NotNull(message = "Indica el precio por km")
        @DecimalMin(value = "0.00", message = "El precio por km no puede ser negativo")
        @Digits(integer = 6, fraction = 2, message = "El precio por km admite hasta 2 decimales") BigDecimal precioKm) {
}
