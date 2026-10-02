package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;

/** Distancia y duracion de una ruta calculada por calles. */
public record RutaResponse(BigDecimal distanciaMetros, Integer duracionSegundos) {

    public RutaResponse {
        if (distanciaMetros == null || distanciaMetros.signum() < 0) {
            throw new IllegalArgumentException("La distancia de OSRM debe ser valida y no negativa");
        }
        if (duracionSegundos == null || duracionSegundos < 0) {
            throw new IllegalArgumentException("La duracion de OSRM debe ser valida y no negativa");
        }
    }
}
