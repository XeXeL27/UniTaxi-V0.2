package com.taxiuap.backend.config.security;

import java.security.Principal;

/**
 * Identidad autenticada extraida de un JWT valido; queda como principal en el SecurityContext.
 *
 * {@code sujeto} es el nombre de usuario (subject del token).
 */
public record JwtUser(Long idUsuario, String sujeto, String rol) implements Principal {

    @Override
    public String getName() {
        // convertAndSendToUser de STOMP enruta los mensajes privados por este nombre, por eso
        // se usa el id de usuario y no el sujeto (el nombre de usuario se repite entre roles de una persona).
        return String.valueOf(idUsuario);
    }
}
