package com.taxiuap.backend.institution.dto;

import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Datos de salida de una carrera. */
public record CarreraResponse(
        Long id,
        Long idInstitucion,
        String nombreInstitucion,
        String nombre,
        EstadoRegistro estado
) {
}
