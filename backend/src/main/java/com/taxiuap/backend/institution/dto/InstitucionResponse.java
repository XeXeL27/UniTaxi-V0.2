package com.taxiuap.backend.institution.dto;

import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Datos de salida de una institucion. */
public record InstitucionResponse(
        Long id,
        Integer idTipoInstitucion,
        String nombreTipoInstitucion,
        String nombre,
        String sigla,
        String ciudad,
        EstadoRegistro estado
) {
}
