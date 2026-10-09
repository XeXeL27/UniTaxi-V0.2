package com.taxiuap.backend.location.dto;

import java.math.BigDecimal;

/**
 * Posicion de un conductor libre, para mostrarlo en el mapa del pasajero (sin datos personales).
 * repartidor: su moto es de la categoria DELIVERY (solo hace entregas); si no, es taxista. El pasajero
 * ve y cuenta solo los del servicio que eligio.
 */
public record ConductorEnLineaResponse(
        Long idConductor,
        BigDecimal latitud,
        BigDecimal longitud,
        Double rumbo,
        boolean repartidor) {
}
