package com.taxiuap.backend.institution.dto;

import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Datos de salida del perfil de estudiante de un pasajero. */
public record DatosEstudianteResponse(
        Long idEstudiante,
        Long idInstitucion,
        String nombreInstitucion,
        String codigoEstudiante,
        EstadoRegistro estado
) {
}
