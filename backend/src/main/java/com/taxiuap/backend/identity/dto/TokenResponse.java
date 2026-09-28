package com.taxiuap.backend.identity.dto;

import java.util.List;

/** Par de tokens JWT (acceso y refresco) mas los datos del usuario autenticado. */
public record TokenResponse(
        String tokenAcceso,
        String tokenRefresco,
        long expiraEnMs,
        UsuarioResponse usuario,
        /** Roles de todas las cuentas activas de la persona (para cambiar de modo en la app). */
        List<String> rolesDisponibles) {
}
