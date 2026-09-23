package com.taxiuap.backend.vehicle.dto;

import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Datos de salida de una categoria de servicio. */
public record CategoriaServicioResponse(
        Integer id,
        Integer idTipoVehiculo,
        String nombreTipoVehiculo,
        String nombre,
        EstadoRegistro estado
) {
}
