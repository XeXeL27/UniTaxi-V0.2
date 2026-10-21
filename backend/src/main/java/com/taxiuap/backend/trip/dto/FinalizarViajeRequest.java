package com.taxiuap.backend.trip.dto;

import com.taxiuap.backend.pricing.enums.MetodoPago;

/**
 * Datos opcionales para finalizar un viaje. Sin metodo de pago se usa el vigente del viaje (el que
 * eligio el pasajero o el que dejo el conductor). pagoRecibido = true: el conductor confirmo en la app
 * que cobro el viaje (efectivo o QR) y queda la hora en viaje.pago_recibido_en. Las apps anteriores no
 * lo envian y el viaje se finaliza igual.
 */
public record FinalizarViajeRequest(MetodoPago metodoPago, Boolean pagoRecibido) {

    public static FinalizarViajeRequest sinDatos() {
        return new FinalizarViajeRequest(null, null);
    }
}
