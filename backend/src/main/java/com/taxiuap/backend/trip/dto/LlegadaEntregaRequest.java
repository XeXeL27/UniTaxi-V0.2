package com.taxiuap.backend.trip.dto;

/** GPS del repartidor al marcar que llego al punto de entrega (B): tiene que estar a 100 m o menos. */
public record LlegadaEntregaRequest(Double latitud, Double longitud) {
}
