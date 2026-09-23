package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/** Datos con los que un conductor oferta sobre una solicitud de viaje. */
public record OfertaViajeRequest(
        @NotNull @Positive BigDecimal precioOfertado,
        @NotNull @Positive Integer tiempoLlegadaMin) {
}
