package com.taxiuap.backend.location.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

import com.taxiuap.backend.location.dto.PosicionConductorMensaje;

import lombok.RequiredArgsConstructor;

/**
 * Publicacion de la posicion de los conductores hacia el topic de los administradores.
 *
 * El destino empieza por /topic/admin/ y por eso el interceptor de WebSocket rechaza la
 * suscripcion de cualquiera que no sea ADMIN, aunque tenga un token valido.
 *
 * El envio va envuelto en try/catch por el mismo motivo que en ViajeEventPublisher: la posicion ya
 * quedo guardada en la base de datos y un broker caido no debe tumbar la transaccion ni el
 * reporte de posicion del conductor.
 */
@Component
@RequiredArgsConstructor
public class ConductorUbicacionPublisher {

    private static final Logger LOG = LoggerFactory.getLogger(ConductorUbicacionPublisher.class);
    private static final String TOPIC_ADMIN = "/topic/admin/conductores";

    private final SimpMessagingTemplate simpMessagingTemplate;

    public void publicarPosicion(PosicionConductorMensaje mensaje) {
        try {
            simpMessagingTemplate.convertAndSend(TOPIC_ADMIN, mensaje);
        } catch (Exception excepcion) {
            LOG.warn("No se pudo publicar la posicion del conductor {} por WebSocket",
                    mensaje.idConductor(), excepcion);
        }
    }
}
