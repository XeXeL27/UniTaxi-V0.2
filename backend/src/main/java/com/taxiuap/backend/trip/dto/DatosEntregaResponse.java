package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;

/** Datos de una entrega expuestos en las respuestas de viaje. */
public record DatosEntregaResponse(
        TipoEnvio tipoEnvio,
        String descripcion,
        BigDecimal costoProductoEstimado,
        BigDecimal costoProductoReal,
        String nombreRemitente,
        String telefonoRemitente,
        String nombreReceptor,
        String telefonoReceptor,
        String codigoRecogida,
        String codigoEntrega,
        String detalleCompraPropuesto,
        String detalleCompra,
        String fotoPaqueteUrl,
        String fotoComprobanteUrl,
        String fotoFallaUrl,
        String motivoFalla,
        EstadoEntrega estadoEntrega) {
}
