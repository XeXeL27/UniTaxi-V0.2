package com.taxiuap.backend.trip.dto;

/**
 * GPS del repartidor al recoger el paquete en A. Sin codigo: basta con haber marcado que llego. La foto
 * del paquete es opcional y viaja aparte (multipart).
 */
public record RecogerPaqueteRequest(Double latitud, Double longitud) {
}
