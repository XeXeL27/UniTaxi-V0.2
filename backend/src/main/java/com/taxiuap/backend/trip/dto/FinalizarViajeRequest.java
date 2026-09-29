package com.taxiuap.backend.trip.dto;

import com.taxiuap.backend.pricing.enums.MetodoPago;

/**
 * Datos opcionales para finalizar un viaje. Sin metodo de pago se usa el vigente del viaje (el que
 * eligio el pasajero o el que dejo el conductor).
 */
public record FinalizarViajeRequest(MetodoPago metodoPago) {
}
