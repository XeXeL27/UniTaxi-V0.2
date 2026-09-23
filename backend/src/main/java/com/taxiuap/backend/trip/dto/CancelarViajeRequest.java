package com.taxiuap.backend.trip.dto;

/**
 * Motivo opcional de la cancelacion de un viaje. El modelo de datos no guarda el motivo en el
 * viaje (solo cancelado_por), pero se recibe para permitir mostrarlo o registrarlo a futuro.
 */
public record CancelarViajeRequest(String motivo) {
}
