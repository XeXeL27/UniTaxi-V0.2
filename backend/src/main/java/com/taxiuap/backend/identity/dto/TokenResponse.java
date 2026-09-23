package com.taxiuap.backend.identity.dto;

/** Par de tokens JWT (acceso y refresco) mas los datos del usuario autenticado. */
public record TokenResponse(
        String tokenAcceso,
        String tokenRefresco,
        long expiraEnMs,
        UsuarioResponse usuario) {
}
