package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Comercio que el repartidor propone antes de comprar. Queda pendiente de confirmacion del cliente:
 * proponer de nuevo invalida la confirmacion anterior.
 */
public record ProponerCompraRequest(
        @Size(max = 255) String puntoCompraWkt,
        @Size(max = 255) String detalleCompra,
        @NotNull(message = "Indica cuanto costaria el producto")
        @DecimalMin(value = "0.01", message = "El monto debe ser mayor que cero")
        BigDecimal costoProducto) {
}
