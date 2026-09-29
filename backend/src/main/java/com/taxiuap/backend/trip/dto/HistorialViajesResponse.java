package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;
import java.util.List;

import com.taxiuap.backend.trip.enums.PeriodoHistorial;

/**
 * Una pagina del historial de viajes completados. totalViajes y totalMonto son del periodo entero
 * (en RECIENTES, de todos los viajes completados), no solo de la pagina.
 */
public record HistorialViajesResponse(
        PeriodoHistorial periodo,
        List<ViajeResponse> viajes,
        int pagina,
        int totalPaginas,
        long totalViajes,
        BigDecimal totalMonto) {
}
