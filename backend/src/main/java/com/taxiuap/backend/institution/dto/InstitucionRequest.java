package com.taxiuap.backend.institution.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Datos de entrada para crear o actualizar una institucion. */
public record InstitucionRequest(

        @NotNull(message = "El tipo de institucion es obligatorio")
        Integer idTipoInstitucion,

        @NotBlank(message = "El nombre es obligatorio")
        @Size(max = 150, message = "El nombre no puede superar 150 caracteres")
        String nombre,

        @Size(max = 30, message = "La sigla no puede superar 30 caracteres")
        String sigla,

        @Size(max = 100, message = "La ciudad no puede superar 100 caracteres")
        String ciudad
) {
}
