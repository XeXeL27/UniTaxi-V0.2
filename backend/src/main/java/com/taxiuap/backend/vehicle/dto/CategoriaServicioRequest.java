package com.taxiuap.backend.vehicle.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Datos de entrada para crear o actualizar una categoria de servicio. */
public record CategoriaServicioRequest(

        @NotNull(message = "El tipo de vehiculo es obligatorio")
        Integer idTipoVehiculo,

        @NotBlank(message = "El nombre es obligatorio")
        @Size(max = 100, message = "El nombre no puede superar 100 caracteres")
        String nombre
) {
}
