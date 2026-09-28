package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

/**
 * Precio del viaje que ven el pasajero antes de confirmar y el conductor antes de aceptar. precio
 * es null cuando no hay precio fijo y el monto se calcula con la tarifa al asignarse el viaje.
 * comisionPorcentaje es lo que la plataforma descuenta al conductor por cada viaje.
 */
public record PrecioViajeResponse(
        BigDecimal precio,
        String moneda,
        BigDecimal comisionPorcentaje) {
}
