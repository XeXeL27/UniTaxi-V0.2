package com.taxiuap.backend.institution.dto;

import java.time.LocalDateTime;

/** Datos de salida de una matricula estudiantil pendiente de revision por el administrador. */
public record VerificacionPendienteResponse(
        Long idMatricula,
        Long idEstudiante,
        String nombreCompleto,
        String codigoEstudiante,
        String nombreInstitucion,
        String nombreCarrera,
        String imagenMatriculaUrl,
        LocalDateTime fechaEnvio
) {
}
