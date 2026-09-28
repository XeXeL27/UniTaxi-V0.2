package com.taxiuap.backend.rating.dto;

import java.time.LocalDateTime;
import java.util.List;

/** Calificacion registrada, con el nombre corto de quien la dio y sus etiquetas. */
public record CalificacionResponse(
        Long id,
        Long idViaje,
        Integer puntuacion,
        String comentario,
        LocalDateTime fecha,
        String nombreEmisor,
        List<String> etiquetas) {
}
