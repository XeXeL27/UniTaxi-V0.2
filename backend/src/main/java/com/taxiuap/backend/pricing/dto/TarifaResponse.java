package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Respuesta de tarifa, incluye los nombres de la categoria de servicio y de la zona. */
public record TarifaResponse(
        Long idTarifa,
        Integer idCategoriaServicio,
        String nombreCategoriaServicio,
        Integer idZona,
        String nombreZona,
        BigDecimal tarifaBase,
        BigDecimal precioKm,
        BigDecimal precioMinuto,
        BigDecimal tarifaMinima,
        LocalDate vigenteDesde,
        LocalDate vigenteHasta) {
}
