package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

import com.taxiuap.backend.pricing.enums.MetodoPago;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import jakarta.validation.Valid;

/**
 * Datos para que un pasajero solicite un viaje. Origen y destino viajan como WKT POINT. Sin
 * categoria de servicio se usa la categoria ESTANDAR (taxi comun). Sin metodo de pago, EFECTIVO.
 */
public record SolicitudViajeRequest(
        Integer idCategoriaServicio,
        @NotBlank String origenWkt,
        @NotBlank String destinoWkt,
        String origenDireccion,
        String destinoDireccion,
        /** Nombre del favorito elegido como destino; solo lo ve el pasajero (el conductor, la direccion). */
        @Size(max = 100) String destinoNombre,
        @PositiveOrZero BigDecimal precioSugerido,
        MetodoPago metodoPago,
        @Valid DatosEntregaRequest datosEntrega,
        /** Viaje para otra persona: quien pide no viaja. Nombre y celular de quien viaja. */
        Boolean paraOtraPersona,
        @Size(max = 150) String nombrePasajeroTercero,
        @Size(max = 20) String telefonoPasajeroTercero,
        /** true: paga quien pide (por QR); false o null: paga quien viaja. */
        Boolean pagaSolicitante) {

    public SolicitudViajeRequest(Integer idCategoriaServicio, String origenWkt, String destinoWkt,
            String origenDireccion, String destinoDireccion, String destinoNombre, BigDecimal precioSugerido,
            MetodoPago metodoPago, DatosEntregaRequest datosEntrega) {
        this(idCategoriaServicio, origenWkt, destinoWkt, origenDireccion, destinoDireccion, destinoNombre,
                precioSugerido, metodoPago, datosEntrega, null, null, null, null);
    }

    public boolean esParaOtraPersona() {
        return Boolean.TRUE.equals(paraOtraPersona);
    }
}
