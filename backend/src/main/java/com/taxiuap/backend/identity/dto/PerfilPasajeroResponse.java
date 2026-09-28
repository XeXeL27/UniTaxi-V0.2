package com.taxiuap.backend.identity.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Datos del perfil de un pasajero: persona, usuario y estadisticas del pasajero. */
public record PerfilPasajeroResponse(
        Long idPasajero,
        String nombres,
        String apellidos,
        String ci,
        String complementoCi,
        LocalDate fechaNacimiento,
        String correo,
        String telefono,
        String fotoUrl,
        BigDecimal calificacionPromedio,
        Integer totalCalificaciones,
        Long idUsuario) {
}
