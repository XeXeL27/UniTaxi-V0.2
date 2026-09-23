package com.taxiuap.backend.institution.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Datos de entrada para crear o actualizar un tipo de institucion. */
public record TipoInstitucionRequest(

        @NotBlank(message = "El codigo es obligatorio")
        @Size(max = 30, message = "El codigo no puede superar 30 caracteres")
        String codigo,

        @NotBlank(message = "El nombre es obligatorio")
        @Size(max = 100, message = "El nombre no puede superar 100 caracteres")
        String nombre
) {
}
