package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.taxiuap.backend.pricing.enums.MetodoPago;
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
        /** Lo que paga el pasajero y cobra el conductor (precio normal menos el descuento de estudiante). */
        BigDecimal precioSugerido,
        boolean precioEstimado,
        SituacionSolicitud situacionSolicitud,
        LocalDateTime fechaSolicitud,
        int cantidadOfertas,
        MetodoPago metodoPago,
        /** Nombre del favorito elegido como destino: solo en las respuestas al pasajero (si no, null). */
        String destinoNombre,
        DatosEntregaResponse datosEntrega,
        /** Precio sin descuento, descuento de estudiante (0 si no tiene) y km por calles. */
        BigDecimal precioNormal,
        BigDecimal descuentoEstudiante,
        BigDecimal distanciaKm) {

    /** La misma solicitud sin el nombre del favorito, para los conductores. */
    public SolicitudViajeResponse sinNombreDestino() {
        return new SolicitudViajeResponse(idSolicitud, idPasajero, nombrePasajero, idCategoriaServicio,
                nombreCategoriaServicio, origenWkt, destinoWkt, origenDireccion, destinoDireccion, precioSugerido,
                precioEstimado,
                situacionSolicitud, fechaSolicitud, cantidadOfertas, metodoPago, null, datosEntrega == null
                        ? null : datosEntrega.paraConductor(),
                precioNormal, descuentoEstudiante, distanciaKm);
    }
}
