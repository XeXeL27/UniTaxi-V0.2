package com.taxiuap.backend.communication.service;

import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import com.taxiuap.backend.communication.dto.MensajeResponse;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Reenvia por WebSocket un mensaje de chat ya guardado a la cola de los dos participantes: el
 * receptor lo recibe en vivo y el emisor ve su burbuja en sus otros telefonos. Lo usan el envio por
 * STOMP y el envio por REST. Si el WebSocket no llega (proxy sin WebSocket, telefono sin senal), el
 * mensaje igual esta guardado y la app lo trae con su consulta de respaldo.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ReenvioChatService {

    private final SimpMessagingTemplate mensajeriaTemplate;

    /** Se llama despues de guardar (fuera de la transaccion de ChatService.enviar). */
    public void reenviar(ChatService.MensajeGuardado guardado) {
        aUsuario(guardado.idUsuarioReceptor(), guardado.mensaje());
        aUsuario(guardado.mensaje().idUsuarioEmisor(), guardado.mensaje());
    }

    private void aUsuario(Long idUsuario, MensajeResponse mensaje) {
        try {
            mensajeriaTemplate.convertAndSendToUser(String.valueOf(idUsuario), "/queue/chat", mensaje);
        } catch (Exception excepcion) {
            log.warn("No se pudo reenviar el mensaje {} al usuario {} por WebSocket",
                    mensaje.idMensaje(), idUsuario, excepcion);
        }
    }
}
