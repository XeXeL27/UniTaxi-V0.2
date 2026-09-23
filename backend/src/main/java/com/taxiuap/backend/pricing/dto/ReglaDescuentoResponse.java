package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Respuesta de regla de descuento estudiantil, incluye nombres del tipo de institucion y vehiculo. */
public record ReglaDescuentoResponse(
        Long idReglaDescuento,
        Integer idTipoInstitucion,
        String nombreTipoInstitucion,
        Integer idTipoVehiculo,
        String nombreTipoVehiculo,
        BigDecimal porcentaje,
        BigDecimal montoMaximo,
        Integer viajesMaximosDia,
        LocalDate vigenteDesde,
        LocalDate vigenteHasta) {
}
