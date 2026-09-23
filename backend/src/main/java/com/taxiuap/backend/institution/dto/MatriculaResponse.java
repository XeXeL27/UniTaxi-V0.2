package com.taxiuap.backend.institution.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;

import com.taxiuap.backend.institution.enums.SituacionVerificacion;

/** Datos de salida de una matricula estudiantil. */
public record MatriculaResponse(
        Long idMatricula,
        Long idCarrera,
        String nombreCarrera,
        String nombreInstitucion,
        String cursoGrado,
        String periodoAcademico,
        String planEstudio,
        String codigoMatricula,
        String imagenMatriculaUrl,
        LocalDateTime fechaMatricula,
        SituacionVerificacion situacionVerificacion,
        LocalDate fechaVencimiento,
        String motivoRechazo
) {
}
