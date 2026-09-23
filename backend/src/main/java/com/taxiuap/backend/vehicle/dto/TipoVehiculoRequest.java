package com.taxiuap.backend.vehicle.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/** Datos de entrada para crear o actualizar un tipo de vehiculo. */
public record TipoVehiculoRequest(

        @NotBlank(message = "El codigo es obligatorio")
        @Size(max = 20, message = "El codigo no puede superar 20 caracteres")
        String codigo,

        @NotBlank(message = "El nombre es obligatorio")
        @Size(max = 100, message = "El nombre no puede superar 100 caracteres")
        String nombre,

        @NotNull(message = "La capacidad de pasajeros es obligatoria")
        @Positive(message = "La capacidad de pasajeros debe ser positiva")
        Integer capacidadPasajeros
) {
}
