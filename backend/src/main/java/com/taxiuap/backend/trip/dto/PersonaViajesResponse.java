package com.taxiuap.backend.trip.dto;

/** Persona que se puede elegir en el filtro de viajes del panel, con cuantos viajes o pedidos tiene. */
public record PersonaViajesResponse(Long idPersona, String nombres, String apellidos, String ci, long viajes) {
}
