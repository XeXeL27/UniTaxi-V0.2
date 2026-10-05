package com.taxiuap.backend.communication.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.taxiuap.backend.communication.entity.Reporte;
import com.taxiuap.backend.communication.enums.SituacionReporte;
import com.taxiuap.backend.communication.enums.TipoResolucionReporte;
import com.taxiuap.backend.trip.entity.DatosEntrega;

/** Proyección administrativa de un incidente y la evidencia DELIVERY asociada. */
public record ReporteResponse(Long id, Long idViaje, Long idUsuarioReporta, String motivo, String descripcion,
        SituacionReporte situacion, LocalDateTime fecha, TipoResolucionReporte tipoResolucion,
        String observacionAdmin, LocalDateTime fechaResolucion, Long idUsuarioAdminResolvio,
        String fotoFallaUrl, String motivoFalla, BigDecimal costoProductoReal, String destinoDireccion,
        String telefonoContacto, String tipoEnvio, String descripcionEntrega, String fotoComprobanteUrl,
        String detalleCompra, String observacionCompra) {

    /** Constructor de compatibilidad para consumidores que solo conocían la evidencia básica. */
    public ReporteResponse(Long id, Long idViaje, Long idUsuarioReporta, String motivo, String descripcion,
            SituacionReporte situacion, LocalDateTime fecha, TipoResolucionReporte tipoResolucion,
            String observacionAdmin, LocalDateTime fechaResolucion, Long idUsuarioAdminResolvio,
            String fotoFallaUrl, String motivoFalla, BigDecimal costoProductoReal, String destinoDireccion) {
        this(id, idViaje, idUsuarioReporta, motivo, descripcion, situacion, fecha, tipoResolucion,
                observacionAdmin, fechaResolucion, idUsuarioAdminResolvio, fotoFallaUrl, motivoFalla,
                costoProductoReal, destinoDireccion, null, null, null, null, null, null);
    }

    public static ReporteResponse de(Reporte reporte) {
        DatosEntrega datos = reporte.getViaje().getSolicitud().getDatosEntrega();
        return new ReporteResponse(reporte.getId(), reporte.getViaje().getId(),
                reporte.getUsuarioReporta().getId(), reporte.getMotivo(), reporte.getDescripcion(),
                reporte.getSituacionReporte(), reporte.getFecha(), reporte.getTipoResolucion(),
                reporte.getObservacionAdmin(), reporte.getFechaResolucion(),
                reporte.getUsuarioAdminResolvio() == null ? null : reporte.getUsuarioAdminResolvio().getId(),
                datos == null ? null : datos.getFotoFallaUrl(), datos == null ? null : datos.getMotivoFalla(),
                datos == null ? null : datos.getCostoProductoReal(),
                reporte.getViaje().getSolicitud().getDestinoDireccion(),
                telefonoContacto(datos, reporte), datos == null || datos.getTipoEnvio() == null
                        ? null : datos.getTipoEnvio().name(), datos == null ? null : datos.getDescripcion(),
                datos == null ? null : datos.getFotoComprobanteUrl(),
                datos == null ? null : datos.getDetalleCompraPropuesto(),
                datos == null ? null : datos.getObservacionCompra());
    }

    private static String telefonoContacto(DatosEntrega datos, Reporte reporte) {
        if (datos == null) return null;
        if (datos.getTelefonoReceptor() != null && !datos.getTelefonoReceptor().isBlank()) {
            return datos.getTelefonoReceptor();
        }
        return reporte.getViaje().getPasajero().getUsuario().getPersona().getTelefono();
    }
}
