package com.taxiuap.backend.rating.dto;

import java.util.List;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Calificacion que el pasajero le da al conductor al terminar el viaje. */
public record CalificacionRequest(
        @NotNull @Min(1) @Max(5) Integer puntuacion,
        @Size(max = 500) String comentario,
        List<Integer> idsEtiquetas) {
}
