package com.taxiuap.backend.location.dto;

import java.math.BigDecimal;
import java.time.Instant;

import com.taxiuap.backend.location.enums.Disponibilidad;

/**
 * Mensaje que se difunde por STOMP a los administradores del panel.
 *
 * Es mas corto que {@link PosicionConductor} a proposito: la trama de tiempo real solo lleva los
 * numeros que cambian, porque el panel ya recibio los nombres y la placa en la consulta de arranque
 * y no los necesita en cada actualizacion.
 */
public record PosicionConductorMensaje(
        Long idConductor,
        BigDecimal latitud,
        BigDecimal longitud,
        Double rumbo,
        Double velocidad,
        Disponibilidad disponibilidad,
        Instant actualizadoEn) {
}
