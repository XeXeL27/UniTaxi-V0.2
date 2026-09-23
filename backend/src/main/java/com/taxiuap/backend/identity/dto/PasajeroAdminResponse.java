package com.taxiuap.backend.identity.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** Datos de un pasajero para el panel admin. */
public record PasajeroAdminResponse(
        Long idPasajero,
        Long idUsuario,
        String nombreUsuario,
        String nombres,
        String apellidos,
        String correo,
        String telefono,
        BigDecimal calificacionPromedio,
        Integer totalCalificaciones,
        LocalDateTime fechaRegistro) {
}
