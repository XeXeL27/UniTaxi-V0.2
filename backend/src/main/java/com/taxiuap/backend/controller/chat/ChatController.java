package com.taxiuap.backend.controller.chat;

import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;

import com.taxiuap.backend.communication.dto.MensajeEnvioRequest;
import com.taxiuap.backend.communication.service.ChatService;
import com.taxiuap.backend.communication.service.ReenvioChatService;
import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.shared.exception.NegocioException;

import lombok.RequiredArgsConstructor;

/**
 * Chat en tiempo real entre el pasajero y el conductor de un viaje.
 *
 * El mensaje llega por STOMP, se guarda en la tabla mensaje (ChatService) y se reenvia a la cola de
 * los dos participantes. Si el otro no esta conectado, el mensaje queda guardado y su app lo trae
 * con la consulta de respaldo. Las apps nuevas envian por REST (Chat*Controller); este camino queda
 * para las versiones anteriores.
 */
@Controller
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;
    private final ReenvioChatService reenvioChatService;

    @MessageMapping("/chat/enviar")
    public void enviar(@Payload MensajeEnvioRequest request, SimpMessageHeaderAccessor acceso) {
        JwtUser usuario = usuarioDe(acceso);
        // Se reenvia a los dos: el receptor lo recibe en vivo y el emisor ve su propia burbuja.
        reenvioChatService.reenviar(chatService.enviar(usuario.idUsuario(), request));
    }

    /**
     * Saca el JwtUser del frame.
     *
     * El interceptor deja un UsernamePasswordAuthenticationToken como principal del STOMP, asi que
     * hay que desarrollarlo para llegar al JwtUser. Se acepta tambien el JwtUser directo porque
     * es lo que devuelve un Principal simple.
     */
    private JwtUser usuarioDe(SimpMessageHeaderAccessor acceso) {
        Object principal = acceso.getUser();
        JwtUser usuario = null;
        if (principal instanceof Authentication autenticacion
                && autenticacion.getPrincipal() instanceof JwtUser desarrollado) {
            usuario = desarrollado;
        } else if (principal instanceof JwtUser directo) {
            usuario = directo;
        }
        if (usuario == null || usuario.idUsuario() == null) {
            throw new NegocioException("El mensaje de chat no tiene un usuario autenticado");
        }
        return usuario;
    }
}
