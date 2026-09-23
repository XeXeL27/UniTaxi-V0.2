package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Respuesta de cupon o promocion de descuento. */
public record DescuentoResponse(
        Long idDescuento,
        String codigo,
        String descripcion,
        BigDecimal porcentaje,
        BigDecimal montoMaximo,
        Integer usosMaximos,
        LocalDate vigenteDesde,
        LocalDate vigenteHasta) {
}
