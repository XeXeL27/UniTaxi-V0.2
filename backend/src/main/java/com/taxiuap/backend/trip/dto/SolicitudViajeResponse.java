package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.taxiuap.backend.trip.enums.SituacionSolicitud;

/** Datos publicos de una solicitud de viaje, para el pasajero dueno o los conductores. */
public record SolicitudViajeResponse(
        Long idSolicitud,
        Long idPasajero,
        String nombrePasajero,
        Integer idCategoriaServicio,
        String nombreCategoriaServicio,
        String origenWkt,
        String destinoWkt,
        String origenDireccion,
        String destinoDireccion,
        BigDecimal precioSugerido,
        SituacionSolicitud situacionSolicitud,
        LocalDateTime fechaSolicitud,
        int cantidadOfertas) {
}
