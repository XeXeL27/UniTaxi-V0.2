package com.taxiuap.backend.identity.dto;

/** Regla comun para validar nombres de usuario en los requests. */
public final class NombreUsuario {

    public static final String PATRON = "^[A-Za-z0-9._-]{3,50}$";

    public static final String MENSAJE = "debe tener de 3 a 50 caracteres: letras, numeros, punto, guion o guion bajo";

    private NombreUsuario() {
    }
}
