package com.taxiuap.backend.institution.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/** Datos de entrada para registrar o actualizar el perfil de estudiante del pasajero autenticado. */
public record DatosEstudianteRequest(

        @NotNull(message = "La institucion es obligatoria")
        Long idInstitucion,

        @NotBlank(message = "El codigo de estudiante es obligatorio")
        String codigoEstudiante
) {
}
