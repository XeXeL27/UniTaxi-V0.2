package com.taxiuap.backend.communication.enums;

/**
 * Desde donde llego el mensaje al administrador: el registro que detecto que la persona ya estaba
 * registrada, o el login (LOGIN; CUENTA_SUSPENDIDA si la contrasena coincidio con una cuenta suspendida).
 */
public enum OrigenAyudaIngreso {
    ESTUDIANTE_UAP,
    REGISTRO_PASAJERO,
    REGISTRO_CONDUCTOR,
    LOGIN,
    CUENTA_SUSPENDIDA
}
