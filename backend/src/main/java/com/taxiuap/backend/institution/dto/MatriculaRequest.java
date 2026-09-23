package com.taxiuap.backend.institution.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/** Datos de entrada para registrar una matricula estudiantil a verificar. */
public record MatriculaRequest(

        @NotNull(message = "La carrera es obligatoria")
        Long idCarrera,

        String cursoGrado,

        String periodoAcademico,

        String planEstudio,

        String codigoMatricula,

        @NotBlank(message = "La imagen de la matricula es obligatoria")
        String imagenMatriculaUrl,

        LocalDate fechaVencimiento
) {
}
