package com.taxiuap.backend.vehicle.dto;

import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Datos de salida de un tipo de vehiculo. */
public record TipoVehiculoResponse(
        Integer id,
        String codigo,
        String nombre,
        Integer capacidadPasajeros,
        EstadoRegistro estado
) {
}
