package com.taxiuap.backend.rating.dto;

import com.taxiuap.backend.rating.enums.AplicaA;
import com.taxiuap.backend.rating.enums.TipoEtiqueta;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Datos de entrada para crear o actualizar una etiqueta de calificacion. */
public record EtiquetaCalificacionRequest(

        @NotBlank(message = "El nombre es obligatorio")
        @Size(max = 100, message = "El nombre no puede superar 100 caracteres")
        String nombre,

        @NotNull(message = "El tipo de etiqueta es obligatorio")
        TipoEtiqueta tipo,

        @NotNull(message = "El actor al que aplica es obligatorio")
        AplicaA aplicaA
) {
}
