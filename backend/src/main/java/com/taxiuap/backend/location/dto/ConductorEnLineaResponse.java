package com.taxiuap.backend.location.dto;

import java.math.BigDecimal;

/** Posicion de un conductor libre, para mostrarlo en el mapa del pasajero (sin datos personales). */
public record ConductorEnLineaResponse(
        Long idConductor,
        BigDecimal latitud,
        BigDecimal longitud,
        Double rumbo) {
}
