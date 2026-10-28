package com.taxiuap.backend.location.dto;

import java.math.BigDecimal;
import java.time.Instant;

import com.taxiuap.backend.location.enums.ActividadPasajero;

/**
 * Pasajero con la app abierta, para el mapa Usuarios en linea del panel. Es tambien el mensaje del
 * topic /topic/admin/pasajeros: enLinea false avisa que cerro o minimizo la app (o dejo de mandar
 * su posicion) y el panel lo quita del mapa.
 */
public record PasajeroEnLineaResponse(
        Long idPasajero,
        Long idUsuario,
        String nombres,
        String apellidos,
        BigDecimal latitud,
        BigDecimal longitud,
        ActividadPasajero actividad,
        Instant actualizadoEn,
        boolean enLinea) {

    public PasajeroEnLineaResponse fuera() {
        return new PasajeroEnLineaResponse(idPasajero, idUsuario, nombres, apellidos, latitud, longitud,
                actividad, actualizadoEn, false);
    }
}
