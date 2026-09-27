package com.taxiuap.backend.controller.conductor;

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

/**
 * Ingesta de la posicion que reporta el conductor por STOMP.
 *
 * No devuelve nada al cliente: el reporte no necesita respuesta. Quien lo necesita es el panel
 * admin, y ese se entera por el topic /topic/admin/conductores, que publica el servicio al
 * guardar. Asi el mismo dato no viaja dos veces de vuelta al conductor.
 */
@Controller
@RequiredArgsConstructor
public class ConductorUbicacionController {

    private final UbicacionService ubicacionService;

    @MessageMapping("/conductor/ubicacion")
    public void registrar(@Payload UbicacionConductorRequest request, SimpMessageHeaderAccessor acc) {
        ubicacionService.registrar(conductorDe(acc).idUsuario(), request);
    }

    /**
     * Saca el JwtUser del frame.
     *
     * El interceptor deja un UsernamePasswordAuthenticationToken como principal del STOMP, asi que
     * hay que desenvolverlo para llegar al JwtUser. Se acepta tambien el JwtUser directo porque
     * es lo que devuelve un Principal simple.
     */
    private JwtUser conductorDe(SimpMessageHeaderAccessor acc) {
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
