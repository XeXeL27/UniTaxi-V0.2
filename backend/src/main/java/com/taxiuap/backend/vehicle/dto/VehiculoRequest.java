package com.taxiuap.backend.vehicle.dto;

import com.taxiuap.backend.identity.dto.ReglasRegistro;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/** Datos de entrada para crear o actualizar un vehiculo del conductor autenticado. */
public record VehiculoRequest(
        @NotBlank String placa,
        @NotBlank @Pattern(regexp = ReglasRegistro.PATRON_MARCA, message = ReglasRegistro.MENSAJE_MARCA) String marca,
        @NotBlank @Pattern(regexp = ReglasRegistro.PATRON_MODELO, message = ReglasRegistro.MENSAJE_MODELO) String modelo,
        @Pattern(regexp = ReglasRegistro.PATRON_COLOR, message = ReglasRegistro.MENSAJE_COLOR) String color,
        @Positive Integer anio,
        @NotNull Integer idTipoVehiculo,
        @NotNull Integer idCategoriaServicio) {
}
