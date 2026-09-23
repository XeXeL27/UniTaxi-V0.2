package com.taxiuap.backend.vehicle.dto;

import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Datos de salida de un vehiculo. */
public record VehiculoResponse(
        Long id,
        String placa,
        String marca,
        String modelo,
        String color,
        Integer anio,
        Integer idTipoVehiculo,
        String nombreTipoVehiculo,
        Integer idCategoriaServicio,
        String nombreCategoriaServicio,
        EstadoRegistro estadoVehiculo) {
}
