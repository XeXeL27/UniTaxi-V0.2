package com.taxiuap.backend.rating.dto;

import com.taxiuap.backend.rating.enums.AplicaA;
import com.taxiuap.backend.rating.enums.TipoEtiqueta;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Datos de salida de una etiqueta de calificacion. */
public record EtiquetaCalificacionResponse(
        Integer id,
        String nombre,
        TipoEtiqueta tipo,
        AplicaA aplicaA,
        EstadoRegistro estado
) {
}
