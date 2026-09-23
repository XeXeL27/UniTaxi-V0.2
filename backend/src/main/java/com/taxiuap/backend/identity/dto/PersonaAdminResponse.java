package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Datos de una persona para el panel admin. tiposUsuario son los roles de sus cuentas activas y
 * nombreUsuario el que comparten sus cuentas de pasajero/conductor (null si aun no tiene).
 */
public record PersonaAdminResponse(
        Long idPersona,
        String ci,
        String complementoCi,
        String nombres,
        String apellidos,
        LocalDate fechaNacimiento,
        String correo,
        String telefono,
        LocalDateTime creadoEn,
        List<String> tiposUsuario,
        String nombreUsuario) {
}
