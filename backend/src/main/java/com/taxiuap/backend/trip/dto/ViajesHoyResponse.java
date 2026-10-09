package com.taxiuap.backend.trip.dto;

/** Cuantos viajes o entregas completo hoy el conductor (solo la cantidad: la app nunca muestra lo ganado). */
public record ViajesHoyResponse(long viajes) {
}
