package com.taxiuap.backend.identity.dto;

/**
 * Resultado del registro desde el panel. carnetPendiente: lo que la app le pedira al ingresar (CARNET,
 * SELFIE o null si el administrador ya subio las tres fotos).
 */
public record RegistroPersonaAdminResponse(Long idPersona, Long idUsuario, String nombreCompleto,
        String nombreUsuario, String correo, boolean estudiante, String carrera, String carnetPendiente) {
}
