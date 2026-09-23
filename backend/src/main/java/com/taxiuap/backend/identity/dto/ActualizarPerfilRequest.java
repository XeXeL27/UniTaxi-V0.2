package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.NotBlank;

/**
 * Datos editables del perfil de un pasajero o conductor. No incluye correo, telefono ni rol:
 * esos campos no se pueden cambiar desde este endpoint.
 */
public record ActualizarPerfilRequest(
        @NotBlank String nombres,
        @NotBlank String apellidos,
        String ci,
        String complementoCi,
        LocalDate fechaNacimiento,
        String fotoUrl) {
}
