package com.taxiuap.backend.communication.enums;

/** Resultado registrado por el administrador al cerrar un incidente DELIVERY. */
public enum TipoResolucionReporte {
    DEVOLUCION_AL_REMITENTE,
    CLIENTE_PAGO_DIRECTO,
    REPARTIDOR_ASUME_PERDIDA,
    CLIENTE_NO_RESPONDIO,
    OTRO
}
