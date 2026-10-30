package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Lo que el repartidor compro de un producto del pedido: conseguido con cantidad y precio unitario (el
 * subtotal lo calcula el servidor) o no conseguido, con una nota opcional.
 */
public record ProductoCompradoRequest(
        @NotNull(message = "Falta el producto") Long idProducto,
        @NotNull(message = "Indica si conseguiste el producto") Boolean conseguido,
        @Min(value = 1, message = "La cantidad debe ser al menos 1")
        @Max(value = 99, message = "La cantidad admite hasta 99") Integer cantidad,
        @DecimalMin(value = "0.01", message = "El precio debe ser mayor que cero")
        @Digits(integer = 6, fraction = 2, message = "El precio admite hasta 2 decimales") BigDecimal precioUnitario,
        @Size(max = 300, message = "La nota admite hasta 300 caracteres") String observacion) {

    @AssertTrue(message = "Indica la cantidad y el precio de cada producto que conseguiste")
    public boolean isDatosCompletos() {
        return !Boolean.TRUE.equals(conseguido) || (cantidad != null && precioUnitario != null);
    }
}
