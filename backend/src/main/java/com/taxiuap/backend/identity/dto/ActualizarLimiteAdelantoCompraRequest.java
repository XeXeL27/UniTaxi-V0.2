package com.taxiuap.backend.identity.dto;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

/** Cambio aislado del monto maximo que un repartidor adelanta para una compra. */
public record ActualizarLimiteAdelantoCompraRequest(
        @NotNull @DecimalMin(value = "0.00") BigDecimal limiteAdelantoCompra,
        String password) {
}
