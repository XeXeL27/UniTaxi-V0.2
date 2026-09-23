package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.taxiuap.backend.trip.enums.SituacionOferta;

/** Datos publicos de una oferta de un conductor sobre una solicitud de viaje. */
public record OfertaViajeResponse(
        Long idOferta,
        Long idSolicitud,
        Long idConductor,
        String nombreConductor,
        BigDecimal calificacionPromedioConductor,
        String placaVehiculo,
        BigDecimal precioOfertado,
        Integer tiempoLlegadaMin,
        SituacionOferta situacionOferta,
        LocalDateTime fechaOferta) {
}
