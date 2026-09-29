package com.taxiuap.backend.trip.dto;

import com.taxiuap.backend.pricing.enums.MetodoPago;

import jakarta.validation.constraints.NotNull;

/** Metodo de pago nuevo de un viaje (EFECTIVO o QR). */
public record CambioMetodoPagoRequest(@NotNull MetodoPago metodoPago) {
}
