package com.taxiuap.backend.trip.dto;

import com.taxiuap.backend.pricing.enums.MetodoPago;

import jakarta.validation.constraints.NotNull;

/** Datos para finalizar un viaje: el metodo con el que el pasajero pago. */
public record FinalizarViajeRequest(@NotNull MetodoPago metodoPago) {
}
