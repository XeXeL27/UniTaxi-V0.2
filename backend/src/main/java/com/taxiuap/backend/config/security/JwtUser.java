package com.taxiuap.backend.config.security;

import java.security.Principal;
import java.time.LocalDateTime;
import java.time.ZoneId;

/**
 * Identidad autenticada extraida de un JWT valido; queda como principal en el SecurityContext.
 *
 * {@code sujeto} es el nombre de usuario (subject del token). {@code emitidoEn}: cuando se emitio el
 * token, en milisegundos (null si no viene de un token).
 */
public record JwtUser(Long idUsuario, String sujeto, String rol, Long emitidoEn) implements Principal {

    public JwtUser(Long idUsuario, String sujeto, String rol) {
        this(idUsuario, sujeto, rol, null);
    }

    /** El token se emitio antes de [desde] (la sesion se corto despues de emitirlo). */
    public boolean emitidoAntesDe(LocalDateTime desde) {
        return desde != null && emitidoEn != null
                && emitidoEn < desde.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli();
    }

    @Override
    public String getName() {
        // convertAndSendToUser de STOMP enruta los mensajes privados por este nombre, por eso
        // se usa el id de usuario y no el sujeto (el nombre de usuario se repite entre roles de una persona).
        return String.valueOf(idUsuario);
    }
}
