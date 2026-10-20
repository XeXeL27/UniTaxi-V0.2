package com.taxiuap.backend.controller.conductor;

import org.springframework.messaging.handler.annotation.MessageExceptionHandler;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;

import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.location.dto.UbicacionConductorRequest;
import com.taxiuap.backend.location.service.UbicacionService;
import com.taxiuap.backend.shared.exception.NegocioException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Ingesta de la posicion que reporta el conductor por STOMP.
 *
 * No devuelve nada al cliente: el reporte no necesita respuesta. Quien lo necesita es el panel
 * admin, y ese se entera por el topic /topic/admin/conductores, que publica el servicio al
 * guardar. Asi el mismo dato no viaja dos veces de vuelta al conductor.
 */
@Slf4j
@Controller
@RequiredArgsConstructor
public class ConductorUbicacionController {

    private final UbicacionService ubicacionService;

    @MessageMapping("/conductor/ubicacion")
    public void registrar(@Payload UbicacionConductorRequest request, SimpMessageHeaderAccessor acc) {
        JwtUser usuario = usuarioDe(acc);
        ubicacionService.registrarPorUsuario(usuario.idUsuario(), usuario.rol(), request);
    }

    /**
     * Un reporte rechazado (conductor no aprobado, de baja...) no llega a nadie: queda en el log, porque si
     * no el conductor nunca aparece "en linea" y no se sabe por que.
     */
    @MessageExceptionHandler(NegocioException.class)
    public void reporteRechazado(NegocioException e, SimpMessageHeaderAccessor acc) {
        log.warn("Posicion del conductor rechazada ({}): {}", acc.getUser() == null ? "sin usuario" : acc.getUser().getName(),
                e.getMessage());
    }

    /**
     * Saca el JwtUser del frame.
     *
     * El interceptor deja un UsernamePasswordAuthenticationToken como principal del STOMP, asi que
     * hay que desarrollarlo para llegar al JwtUser. Se acepta tambien el JwtUser directo porque
     * es lo que devuelve un Principal simple.
     */
    private JwtUser usuarioDe(SimpMessageHeaderAccessor acc) {
        Object principal = acc.getUser();
        JwtUser usuario = null;
        if (principal instanceof Authentication autenticacion
                && autenticacion.getPrincipal() instanceof JwtUser developing) {
            usuario = developing;
        } else if (principal instanceof JwtUser directo) {
            usuario = directo;
        }
        if (usuario == null || usuario.idUsuario() == null) {
            throw new NegocioException("El reporte de posicion no tiene un conductor autenticado");
        }
        return usuario;
    }
}
