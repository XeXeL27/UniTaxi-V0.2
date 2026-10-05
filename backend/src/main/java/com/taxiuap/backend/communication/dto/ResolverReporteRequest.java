package com.taxiuap.backend.communication.dto;

import com.taxiuap.backend.communication.enums.SituacionReporte;
import com.taxiuap.backend.communication.enums.TipoResolucionReporte;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Datos de la resolución administrativa de un reporte. */
public record ResolverReporteRequest(
        @NotNull TipoResolucionReporte tipoResolucion,
        @Size(max = 1000) String observacionAdmin,
        @NotNull SituacionReporte situacion) {
}
