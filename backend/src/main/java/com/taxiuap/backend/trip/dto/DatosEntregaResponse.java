package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.trip.entity.DatosEntrega;

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

    public DatosEntregaResponse paraConductor() {
        return new DatosEntregaResponse(tipoEnvio, descripcion, costoProductoEstimado, costoProductoReal,
                nombreRemitente, telefonoRemitente, nombreReceptor, telefonoReceptor, null, null,
                detalleCompraPropuesto, detalleCompra, fotoPaqueteUrl, fotoComprobanteUrl, fotoFallaUrl,
                motivoFalla, estadoEntrega);
    }

    public static DatosEntregaResponse desde(DatosEntrega datos, boolean mostrarCodigos) {
        if (datos == null) return null;
        DatosEntregaResponse respuesta = new DatosEntregaResponse(datos.getTipoEnvio(), datos.getDescripcion(),
                datos.getCostoProductoEstimado(), datos.getCostoProductoReal(), datos.getNombreRemitente(),
                datos.getTelefonoRemitente(), datos.getNombreReceptor(), datos.getTelefonoReceptor(),
                datos.getCodigoRecogida(), datos.getCodigoEntrega(), datos.getDetalleCompraPropuesto(),
                datos.getDetalleCompra(), datos.getFotoPaqueteUrl(), datos.getFotoComprobanteUrl(),
                datos.getFotoFallaUrl(), datos.getMotivoFalla(), datos.getEstadoEntrega());
        return mostrarCodigos ? respuesta : respuesta.paraConductor();
    }
}
