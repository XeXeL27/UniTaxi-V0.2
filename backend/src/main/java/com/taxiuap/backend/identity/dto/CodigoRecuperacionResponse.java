package com.taxiuap.backend.identity.dto;

/**
 * Codigo enviado: envio N de maximo, cuantos segundos vale y cuantos faltan para pedir otro (despues
 * del ultimo, la espera larga). puedeMensaje: ya uso todos los envios y puede escribir al administrador.
 */
public record CodigoRecuperacionResponse(
        int envio,
        int maximo,
        long segundosVigencia,
        long segundosReenvio,
        boolean puedeMensaje,
        String correo) {
}
