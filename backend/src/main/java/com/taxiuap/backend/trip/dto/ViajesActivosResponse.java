package com.taxiuap.backend.trip.dto;

import java.util.List;

/**
 * Servicios en curso de quien consulta y cuantos puede tener a la vez: el pasajero hasta 2 (taxi o
 * entrega, con una sola solicitud esperando), el repartidor hasta 3 pedidos y el taxista 1 viaje.
 */
public record ViajesActivosResponse(List<ViajeResponse> viajes, int maximo) {
}
