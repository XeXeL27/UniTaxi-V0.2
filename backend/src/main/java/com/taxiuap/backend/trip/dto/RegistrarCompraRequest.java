package com.taxiuap.backend.trip.dto;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Compra ya realizada por el repartidor: donde compro, el comercio, cada producto del pedido (conseguido
 * con su precio o no conseguido) y una observacion opcional. La foto del recibo es opcional y viaja aparte
 * porque es un archivo. Volver a enviarla antes del pago corrige los precios y pide al cliente aceptar de
 * nuevo el costo total.
 */
public record RegistrarCompraRequest(
        @NotBlank(message = "Indica donde compraste el producto")
        String puntoCompraWkt,
        @NotBlank(message = "Describe el comercio donde compraste")
        @Size(max = 255) String detalleCompra,
        @Size(max = 500) String observacionCompra,
        // Sin lista (apps de antes de los productos): EntregaService responde que hay que actualizar UNITAXI.
        @Valid List<ProductoCompradoRequest> productos) {
}
