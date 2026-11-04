package com.taxiuap.backend.trip.dto;

import jakarta.validation.constraints.Size;

/**
 * Entrega en B, sin codigo ni foto. Si recibe otra persona (pedido para otra persona), el repartidor le
 * pregunta su nombre completo y lo escribe: tiene que ser el que dio el cliente. Si recibe el mismo
 * cliente no se pide nada. Latitud y longitud son el GPS del telefono (a 100 m o menos de B).
 */
public record EntregarPedidoRequest(
        @Size(max = 150, message = "El nombre admite hasta 150 caracteres") String nombreReceptor,
        Double latitud,
        Double longitud) {
}
