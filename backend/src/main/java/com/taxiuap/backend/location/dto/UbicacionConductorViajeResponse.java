package com.taxiuap.backend.location.dto;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Posicion del conductor asignado a un viaje, para que el pasajero vea en tiempo real de donde
 * viene, a que distancia esta y cuanto tarda en llegar.
 *
 * La distancia se calcula en linea recta (PostGIS) desde la posicion del conductor hasta el
 * punto de referencia del viaje (origen mientras va a recoger, destino durante el viaje).
 */
public record UbicacionConductorViajeResponse(
        Long idViaje,
        BigDecimal latitud,
        BigDecimal longitud,
        Double rumbo,
        Double velocidad,
        Instant actualizadoEn,
        Double distanciaMetros,
        String puntoReferencia) {
}
