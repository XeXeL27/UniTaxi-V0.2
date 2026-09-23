package com.taxiuap.backend.institution.dto;

import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Datos de salida de un tipo de institucion. */
public record TipoInstitucionResponse(
        Integer id,
        String codigo,
        String nombre,
        EstadoRegistro estado
) {
}
