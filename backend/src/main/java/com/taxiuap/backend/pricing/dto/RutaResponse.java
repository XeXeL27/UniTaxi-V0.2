package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;

/** Distancia y duracion de una ruta calculada por calles. */
public record RutaResponse(BigDecimal distanciaMetros, Integer duracionSegundos) {
}
