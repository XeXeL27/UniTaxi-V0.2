package com.taxiuap.backend.rating.dto;

import java.math.BigDecimal;
import java.util.List;

/** Promedio y comentarios que recibio el conductor de sus pasajeros. */
public record CalificacionesRecibidasResponse(
        BigDecimal promedio,
        Integer total,
        List<CalificacionResponse> calificaciones) {
}
