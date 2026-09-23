package com.taxiuap.backend.location.dto;

/** Respuesta de zona con el poligono serializado como texto WKT. */
public record ZonaResponse(
        Integer idZona,
        String nombre,
        String poligonoWkt) {
}
