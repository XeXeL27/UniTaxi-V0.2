package com.taxiuap.backend.vehicle.dto;

import jakarta.validation.constraints.NotNull;

/**
 * Datos para corregir la categoria de servicio de un vehiculo desde la administracion.
 *
 * [idVehiculo] es opcional: sin el se cambia el unico vehiculo activo del conductor, y si tiene
 * mas de uno el backend responde 422 para que se indique cual, en vez de cambiar el equivocado.
 */
public record CambiarCategoriaVehiculoRequest(
        @NotNull Integer idCategoriaServicio,
        Integer idVehiculo) {
}
