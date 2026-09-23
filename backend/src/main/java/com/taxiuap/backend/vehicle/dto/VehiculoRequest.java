package com.taxiuap.backend.vehicle.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/** Datos de entrada para crear o actualizar un vehiculo del conductor autenticado. */
public record VehiculoRequest(
        @NotBlank String placa,
        @NotBlank String marca,
        @NotBlank String modelo,
        String color,
        @Positive Integer anio,
        @NotNull Integer idTipoVehiculo,
        @NotNull Integer idCategoriaServicio) {
}
