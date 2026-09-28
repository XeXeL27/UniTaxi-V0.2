package com.taxiuap.backend.identity.dto;

/** Datos de Google con que la app llena el formulario de conductor (no se pueden cambiar ahi). */
public record PerfilGoogleResponse(String correo, String nombres, String apellidos) {
}
