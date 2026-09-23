package com.taxiuap.backend.identity.dto;

/** Datos publicos de un usuario autenticado. */
public record UsuarioResponse(
        Long idUsuario,
        String nombreUsuario,
        String nombres,
        String apellidos,
        String correo,
        String telefono,
        String rol) {
}
