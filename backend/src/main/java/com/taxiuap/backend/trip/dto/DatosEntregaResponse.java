package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

import org.locationtech.jts.geom.Point;
import org.locationtech.jts.io.WKTWriter;

import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;

/** Datos de una entrega expuestos en las respuestas de viaje. */
public record DatosEntregaResponse(
        TipoEnvio tipoEnvio,
        String descripcion,
        BigDecimal costoProductoEstimado,
        BigDecimal costoProductoReal,
        BigDecimal costoProductoConfirmado,
        Boolean compraConfirmadaPorCliente,
        Boolean pagoConfirmado,
        BigDecimal montoPagoRecibido,
        String nombreRemitente,
        String telefonoRemitente,
        String nombreReceptor,
        String telefonoReceptor,
        String codigoRecogida,
        String codigoEntrega,
        String detalleCompraPropuesto,
        String detalleCompra,
        String puntoCompraPropuestoWkt,
        String puntoCompraWkt,
        String fotoPaqueteUrl,
        String fotoComprobanteUrl,
        String fotoFallaUrl,
        String motivoFalla,
        EstadoEntrega estadoEntrega) {

    /**
     * Vista del repartidor: sin codigos. Se los dicta la persona que se los tiene que dictar y por eso
     * la API nunca los devuelve, aunque el repartidor tenga el viaje abierto.
     */
    public DatosEntregaResponse paraConductor() {
        return new DatosEntregaResponse(tipoEnvio, descripcion, costoProductoEstimado, costoProductoReal,
                costoProductoConfirmado, compraConfirmadaPorCliente, pagoConfirmado, montoPagoRecibido,
                nombreRemitente, telefonoRemitente, nombreReceptor, telefonoReceptor, null, null,
                detalleCompraPropuesto, detalleCompra, puntoCompraPropuestoWkt, puntoCompraWkt, fotoPaqueteUrl,
                fotoComprobanteUrl, fotoFallaUrl, motivoFalla, estadoEntrega);
    }

    public static DatosEntregaResponse desde(DatosEntrega datos, boolean mostrarCodigos) {
        if (datos == null) {
            return null;
        }
        DatosEntregaResponse respuesta = new DatosEntregaResponse(datos.getTipoEnvio(), datos.getDescripcion(),
                datos.getCostoProductoEstimado(), datos.getCostoProductoReal(), datos.getCostoProductoConfirmado(),
                datos.getCompraConfirmadaPorCliente(), datos.getPagoConfirmado(), datos.getMontoPagoRecibido(),
                datos.getNombreRemitente(), datos.getTelefonoRemitente(), datos.getNombreReceptor(),
                datos.getTelefonoReceptor(), datos.getCodigoRecogida(), datos.getCodigoEntrega(),
                datos.getDetalleCompraPropuesto(), datos.getDetalleCompra(),
                aWkt(datos.getPuntoCompraPropuesto()), aWkt(datos.getPuntoCompra()), datos.getFotoPaqueteUrl(),
                datos.getFotoComprobanteUrl(), datos.getFotoFallaUrl(), datos.getMotivoFalla(),
                datos.getEstadoEntrega());
        return mostrarCodigos ? respuesta : respuesta.paraConductor();
    }

    /** Los puntos van como texto porque la app los dibuja en el mapa y no necesita la columna cruda. */
    private static String aWkt(Point punto) {
        return punto == null ? null : new WKTWriter().write(punto);
    }
}
