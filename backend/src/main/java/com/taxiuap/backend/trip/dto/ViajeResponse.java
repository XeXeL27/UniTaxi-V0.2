package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.taxiuap.backend.pricing.enums.MetodoPago;
import com.taxiuap.backend.trip.enums.CanceladoPor;
import com.taxiuap.backend.trip.enums.SituacionViaje;

/** Datos de un viaje expuestos a pasajero y conductor. */
public record ViajeResponse(
        Long idViaje,
        Long idSolicitud,
        Long idPasajero,
        String nombrePasajero,
        Long idConductor,
        String nombreConductor,
        String placaVehiculo,
        String marcaVehiculo,
        String modeloVehiculo,
        String colorVehiculo,
        BigDecimal calificacionConductor,
        String origenWkt,
        String destinoWkt,
        String origenDireccion,
        String destinoDireccion,
        BigDecimal distanciaKm,
        Integer duracionMin,
        BigDecimal precioOriginal,
        BigDecimal montoDescuento,
        BigDecimal precioFinal,
        SituacionViaje situacionViaje,
        CanceladoPor canceladoPor,
        LocalDateTime fechaInicio,
        LocalDateTime fechaFin,
        boolean calificadoPorPasajero,
        MetodoPago metodoPago,
        /** Cambio de metodo que pidio el pasajero y el conductor todavia no respondio (o null). */
        MetodoPago metodoPagoPedido,
        /** true si el conductor tiene al menos un QR de cobro. */
        boolean conductorTieneQr,
        /** true si al pasajero ya se le ofrecio calificar este viaje (no se vuelve a ofrecer). */
        boolean calificacionOfrecida) {
}
