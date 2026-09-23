package com.taxiuap.backend.location.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Datos de entrada para crear o actualizar una zona.
 *
 * El poligono se recibe como texto WKT (Well-Known Text, por ejemplo
 * "POLYGON((-68.77 -11.01, -68.76 -11.01, -68.76 -11.00, -68.77 -11.00, -68.77 -11.01))")
 * en lugar de GeoJSON porque JTS (org.locationtech.jts.io.WKTReader / WKTWriter, ya incluido
 * por la dependencia hibernate-spatial) lee y escribe WKT de forma nativa, sin necesidad de
 * agregar una dependencia extra solo para soportar GeoJSON.
 */
public record ZonaRequest(
        @NotBlank String nombre,
        @NotBlank String poligonoWkt) {
}
