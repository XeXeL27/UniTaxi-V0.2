package com.taxiuap.backend.identity.enums;

/** Tipo de cuenta que el administrador habilita para una persona. */
public enum TipoRegistroUsuario {
    PASAJERO,
    CONDUCTOR,
    /** Pasajero y conductor, con el mismo nombre de usuario y contrasena. */
    AMBOS,
    ADMIN
}
