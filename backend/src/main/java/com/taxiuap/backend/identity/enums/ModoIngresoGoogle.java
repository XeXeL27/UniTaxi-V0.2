package com.taxiuap.backend.identity.enums;

/**
 * Para que se pidio el ingreso con Google desde la app.
 *
 * INGRESO: boton del login; entra con la cuenta que ya tenga (pasajero primero) o, si no tiene
 * ninguna, se registra como pasajero. PASAJERO: registro de pasajero. CONDUCTOR: registro de
 * conductor; si todavia no es conductor la app debe completar el formulario (licencia, moto y PDF).
 */
public enum ModoIngresoGoogle {
    INGRESO,
    PASAJERO,
    CONDUCTOR
}
