package com.taxiuap.backend.pricing.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/** Descuento fijo del estudiante UAP por viaje (Bs enteros) y viajes con descuento por dia (null: sin limite). */
public record DescuentoEstudianteRequest(
        @NotNull @Min(value = 0, message = "El descuento no puede ser negativo") @Max(1000) Integer descuentoEstudiante,
        @Min(value = 1, message = "Los viajes con descuento por día deben ser al menos 1") @Max(100) Integer viajesEstudiantePorDia) {
}
