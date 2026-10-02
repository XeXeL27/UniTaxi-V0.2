package com.taxiuap.backend.identity.dto;

import java.time.LocalDateTime;

/** Datos de una cuenta de usuario para el panel admin. */
public record UsuarioAdminResponse(
        Long idUsuario,
        Long idPersona,
        String nombres,
        String apellidos,
        String ci,
        String nombreUsuario,
        String correo,
        String telefono,
        String rol,
        LocalDateTime fechaRegistro,
        /** A (activa) o S (suspendida). */
        String estado,
        /** HABILITADO, PENDIENTE (conductor en revision), OBSERVADO (carnet en revision), RECHAZADO o SUSPENDIDO. */
        String situacion) {
}
