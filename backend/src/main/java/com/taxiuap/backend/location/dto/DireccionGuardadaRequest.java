package com.taxiuap.backend.location.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Datos de entrada para crear o actualizar una direccion guardada del pasajero autenticado.
 *
 * La ubicacion se recibe como texto WKT (por ejemplo "POINT(-68.76 -11.02)"), igual que el
 * poligono de ZonaRequest.
 */
public record DireccionGuardadaRequest(
        @NotBlank String nombre,
        @NotBlank String direccion,
        @NotBlank String ubicacionWkt) {
}
