package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Compra ya realizada por el repartidor: donde lo compro, que compro, cuanto costo y, si no hay
 * comprobante o hay algo particular, la observacion. La foto del recibo es opcional y viaja aparte
 * porque es un archivo.
 */
public record RegistrarCompraRequest(
        @NotBlank(message = "Indica donde compraste el producto")
        String puntoCompraWkt,
        @NotBlank(message = "Describe el comercio donde compraste")
        @Size(max = 255) String detalleCompra,
        @NotNull(message = "Registra cuanto costo el producto")
        @DecimalMin(value = "0.01", message = "El monto debe ser mayor que cero")
        BigDecimal costoProducto,
        @Size(max = 500) String observacionCompra) {
}
