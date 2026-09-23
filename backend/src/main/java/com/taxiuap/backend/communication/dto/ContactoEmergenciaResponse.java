package com.taxiuap.backend.communication.dto;

/** Datos de salida de un contacto de emergencia. */
public record ContactoEmergenciaResponse(
        Long id,
        String nombre,
        String telefono,
        String parentesco) {
}
