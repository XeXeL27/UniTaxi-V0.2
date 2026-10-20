package com.taxiuap.backend.config;

import java.security.Principal;

import org.springframework.context.event.EventListener;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import com.taxiuap.backend.config.security.JwtUser;

import lombok.extern.slf4j.Slf4j;

/**
 * Deja en el log cuando una app se conecta o se desconecta del WebSocket (STOMP), con su usuario y rol.
 * Sin esto no se sabe si un conductor que no aparece "en linea" llego a conectarse (su GPS solo viaja por
 * aqui) o si la conexion se cae seguido (cambio de wifi a datos, proxy que la corta).
 */
@Slf4j
@Component
public class RegistroSesionesWebSocket {

    @EventListener
    public void conectado(SessionConnectedEvent evento) {
        log.info("WebSocket conectado: {}", quien(evento.getUser()));
    }

    @EventListener
    public void desconectado(SessionDisconnectEvent evento) {
        log.info("WebSocket desconectado: {} ({})", quien(evento.getUser()), evento.getCloseStatus());
    }

    private static String quien(Principal principal) {
        Object usuario = principal instanceof Authentication autenticacion ? autenticacion.getPrincipal() : principal;
        if (usuario instanceof JwtUser jwt) {
            return jwt.sujeto() + "/" + jwt.rol();
        }
        return principal == null ? "sin usuario" : principal.getName();
    }
}
