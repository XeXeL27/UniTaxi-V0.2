package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import org.locationtech.jts.geom.Point;
import org.locationtech.jts.io.WKTWriter;

import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.MotivoFallaEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;

/**
 * Datos de una entrega expuestos en las respuestas de viaje. En una compra van tambien los productos
 * (lo pedido y lo comprado) y los costos totales presentados al cliente, del mas nuevo al mas viejo.
 */
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
        EstadoEntrega estadoEntrega,
        LocalDateTime fechaLlegadaRecogida,
        LocalDateTime fechaRecogida,
        LocalDateTime fechaEntrega,
        String fotoRecogidaUrl,
        String fotoEntregaUrl,
        String ubicacionRecogidaWkt,
        String ubicacionEntregaWkt,
        String receptorIdentificado,
        LocalDateTime fechaLlegadaEntrega,
        Integer avisosEntrega,
        LocalDateTime ultimoAvisoEntrega,
        String observacionCompra,
        BigDecimal tarifaBaseAplicada,
        BigDecimal precioKmAplicado,
        List<ProductoEntregaResponse> productos,
        List<PropuestaCostoResponse> propuestas,
        MotivoFallaEntrega tipoFalla) {

    /**
     * Vista del repartidor: sin codigos. Se los dicta la persona que se los tiene que dictar y por eso
     * la API nunca los devuelve, aunque el repartidor tenga el viaje abierto. Tampoco las fotos de
     * recogida y entrega: en su historial solo ve el detalle del pedido; la evidencia es del admin.
     */
    public DatosEntregaResponse paraConductor() {
        return copia(null, null, null, null);
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
                datos.getEstadoEntrega(), datos.getFechaLlegadaRecogida(), datos.getFechaRecogida(),
                datos.getFechaEntrega(), datos.getFotoRecogidaUrl(), datos.getFotoEntregaUrl(),
                aWkt(datos.getUbicacionRecogida()), aWkt(datos.getUbicacionEntrega()),
                datos.getReceptorIdentificado(), datos.getFechaLlegadaEntrega(), datos.getAvisosEntrega(),
                datos.getUltimoAvisoEntrega(), datos.getObservacionCompra(), datos.getTarifaBaseAplicada(),
                datos.getPrecioKmAplicado(),
                datos.getProductos() == null ? List.of() : datos.getProductos().stream()
                        .filter(p -> p.getEstadoProductoEntrega() == EstadoRegistro.A)
                        .map(ProductoEntregaResponse::de)
                        .toList(),
                datos.getPropuestas() == null ? List.of() : datos.getPropuestas().stream()
                        .filter(p -> p.getEstadoPropuestaCosto() == EstadoRegistro.A)
                        .map(PropuestaCostoResponse::de)
                        .toList(),
                datos.getTipoFalla());
        return mostrarCodigos ? respuesta : respuesta.paraConductor();
    }

    /** Vista del panel admin: todo el pedido con su evidencia, pero sin los codigos de recogida y entrega. */
    public static DatosEntregaResponse paraAdmin(DatosEntrega datos) {
        DatosEntregaResponse completo = desde(datos, true);
        return completo == null ? null : completo.copia(null, null, completo.fotoRecogidaUrl, completo.fotoEntregaUrl);
    }

    /** La propuesta vigente (la mas nueva), o null si el repartidor todavia no registro la compra. */
    public PropuestaCostoResponse propuestaVigente() {
        return propuestas == null || propuestas.isEmpty() ? null : propuestas.get(0);
    }

    private DatosEntregaResponse copia(String codigoRecogida, String codigoEntrega, String fotoRecogidaUrl,
            String fotoEntregaUrl) {
        return new DatosEntregaResponse(tipoEnvio, descripcion, costoProductoEstimado, costoProductoReal,
                costoProductoConfirmado, compraConfirmadaPorCliente, pagoConfirmado, montoPagoRecibido,
                nombreRemitente, telefonoRemitente, nombreReceptor, telefonoReceptor, codigoRecogida, codigoEntrega,
                detalleCompraPropuesto, detalleCompra, puntoCompraPropuestoWkt, puntoCompraWkt, fotoPaqueteUrl,
                fotoComprobanteUrl, fotoFallaUrl, motivoFalla, estadoEntrega, fechaLlegadaRecogida, fechaRecogida,
                fechaEntrega, fotoRecogidaUrl, fotoEntregaUrl, ubicacionRecogidaWkt, ubicacionEntregaWkt,
                receptorIdentificado, fechaLlegadaEntrega, avisosEntrega, ultimoAvisoEntrega, observacionCompra,
                tarifaBaseAplicada, precioKmAplicado, productos, propuestas, tipoFalla);
    }

    /** Los puntos van como texto porque la app los dibuja en el mapa y no necesita la columna cruda. */
    private static String aWkt(Point punto) {
        return punto == null ? null : new WKTWriter().write(punto);
    }
}
