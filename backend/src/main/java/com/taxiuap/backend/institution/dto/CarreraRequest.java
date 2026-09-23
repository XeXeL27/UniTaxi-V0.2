package com.taxiuap.backend.institution.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Datos de entrada para crear o actualizar una carrera. */
public record CarreraRequest(

        @NotNull(message = "La institucion es obligatoria")
        Long idInstitucion,

        @NotBlank(message = "El nombre es obligatorio")
        @Size(max = 150, message = "El nombre no puede superar 150 caracteres")
        String nombre
) {
}
