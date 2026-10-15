package com.taxiuap.backend.identity.dto;

import java.time.LocalDateTime;

/**
 * Si la persona ya esta registrada. recuperacion: identificador temporal para pedir los codigos al
 * correo registrado (correo, a medias) o el mensaje al administrador; los datos de la persona nunca
 * salen del servidor. puedeRecibirCodigo false: sin correo o sin cuenta de la app, solo queda el
 * mensaje y sinCodigo dice por que (sin correo, cuenta suspendida). bloqueadoHasta: ya envio un mensaje
 * al administrador y espera 24 horas.
 */
public record CuentaRegistradaResponse(
        boolean registrado,
        String recuperacion,
        String correo,
        boolean puedeRecibirCodigo,
        String sinCodigo,
        LocalDateTime bloqueadoHasta) {

    public static CuentaRegistradaResponse noRegistrado() {
        return new CuentaRegistradaResponse(false, null, null, false, null, null);
    }
}
