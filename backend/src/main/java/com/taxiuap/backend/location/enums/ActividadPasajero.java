package com.taxiuap.backend.location.enums;

/** Que esta haciendo un pasajero en linea, para el mapa Usuarios en linea del panel. */
public enum ActividadPasajero {
    /** Con la app abierta, sin solicitud ni viaje. */
    LIBRE,
    /** Tiene una solicitud esperando conductor. */
    BUSCANDO,
    /** Tiene un viaje o pedido sin terminar. */
    EN_VIAJE
}
