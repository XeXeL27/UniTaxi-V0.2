package com.taxiuap.backend.location.dto;

import java.math.BigDecimal;
import java.time.Instant;

import com.taxiuap.backend.location.enums.Disponibilidad;

/**
 * Posicion de un conductor en la lista de flota que consume el panel admin.
 *
 * Se construye con un constructor simple porque es una salida de la API, no una entrada: la
 * validacion del {@link UbicacionConductorRequest} es la que protege los datos.
 */
public record PosicionConductor(
        Long idConductor,
        String nombres,
        String apellidos,
        String placa,
        BigDecimal latitud,
        BigDecimal longitud,
        Double rumbo,
        Double velocidad,
        Disponibilidad disponibilidad,
        Instant actualizadoEn) {
}
