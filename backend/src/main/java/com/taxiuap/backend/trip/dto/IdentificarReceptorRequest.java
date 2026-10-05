package com.taxiuap.backend.trip.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Quien recibio el pedido en COMPRA_Y_ENTREGA. El receptor siempre es el cliente que creo el pedido,
 * asi que nombre y telefono se comparan contra sus datos: no se acepta que otro firme por el.
 */
public record IdentificarReceptorRequest(
        @NotBlank(message = "Ingresa el nombre de quien recibio")
        @Size(max = 150) String nombre,
        @Size(max = 30) String telefono) {
}
