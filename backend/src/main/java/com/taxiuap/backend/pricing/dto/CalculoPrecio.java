package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;

import com.taxiuap.backend.institution.entity.Estudiante;
import com.taxiuap.backend.pricing.entity.ReglaDescuentoEstudiantil;
import com.taxiuap.backend.pricing.entity.Tarifa;

/**
 * Resultado del calculo de precio de un viaje: precio original (de la oferta o de la tarifa),
 * el descuento estudiantil aplicado (si corresponde) y el precio final a cobrar.
 */
public record CalculoPrecio(
        BigDecimal precioOriginal,
        BigDecimal montoDescuento,
        BigDecimal precioFinal,
        Tarifa tarifa,
        ReglaDescuentoEstudiantil regla,
        Estudiante estudiante,
        BigDecimal distanciaKm,
        Integer duracionMin) {
}
