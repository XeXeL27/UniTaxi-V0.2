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
        String fotoFallaUrl, String motivoFalla, BigDecimal costoProductoReal, String destinoDireccion) {

    public static ReporteResponse de(Reporte reporte) {
        DatosEntrega datos = reporte.getViaje().getSolicitud().getDatosEntrega();
        return new ReporteResponse(reporte.getId(), reporte.getViaje().getId(),
                reporte.getUsuarioReporta().getId(), reporte.getMotivo(), reporte.getDescripcion(),
                reporte.getSituacionReporte(), reporte.getFecha(), reporte.getTipoResolucion(),
                reporte.getObservacionAdmin(), reporte.getFechaResolucion(),
                reporte.getUsuarioAdminResolvio() == null ? null : reporte.getUsuarioAdminResolvio().getId(),
                datos == null ? null : datos.getFotoFallaUrl(), datos == null ? null : datos.getMotivoFalla(),
                datos == null ? null : datos.getCostoProductoReal(),
                reporte.getViaje().getSolicitud().getDestinoDireccion());
    }
}
