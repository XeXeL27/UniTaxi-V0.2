package com.taxiuap.backend.trip.dto;

import jakarta.validation.constraints.NotNull;

/** Respuesta del conductor al cambio de metodo de pago que pidio el pasajero. */
public record RespuestaCambioPagoRequest(@NotNull Boolean aceptar) {
}
