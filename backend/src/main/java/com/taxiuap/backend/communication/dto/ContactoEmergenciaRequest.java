package com.taxiuap.backend.communication.dto;

import jakarta.validation.constraints.NotBlank;

/** Datos de entrada para crear o actualizar un contacto de emergencia del usuario autenticado. */
public record ContactoEmergenciaRequest(
        @NotBlank String nombre,
        @NotBlank String telefono,
        String parentesco) {
}
