package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

import com.taxiuap.backend.pricing.enums.MetodoPago;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

/**
 * Datos para que un pasajero solicite un viaje. Origen y destino viajan como WKT POINT. Sin
 * categoria de servicio se usa la categoria ESTANDAR (taxi comun). Sin metodo de pago, EFECTIVO.
 */
public record SolicitudViajeRequest(
        Integer idCategoriaServicio,
        @NotBlank String origenWkt,
        @NotBlank String destinoWkt,
        String origenDireccion,
        String destinoDireccion,
        /** Nombre del favorito elegido como destino; solo lo ve el pasajero (el conductor, la direccion). */
        @Size(max = 100) String destinoNombre,
        @PositiveOrZero BigDecimal precioSugerido,
        MetodoPago metodoPago) {
}
