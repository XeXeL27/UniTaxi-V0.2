package com.taxiuap.backend.location.dto;

/** Respuesta de direccion guardada con la ubicacion serializada como texto WKT. */
public record DireccionGuardadaResponse(
        Long id,
        String nombre,
        String direccion,
        String ubicacionWkt) {
}
