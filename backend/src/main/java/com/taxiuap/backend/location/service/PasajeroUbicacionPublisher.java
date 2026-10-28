package com.taxiuap.backend.location.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

import com.taxiuap.backend.location.dto.PasajeroEnLineaResponse;

import lombok.RequiredArgsConstructor;

/**
 * Publica la posicion de los pasajeros en linea hacia el topic de los administradores. Igual que
 * {@link ConductorUbicacionPublisher}: el prefijo /topic/admin/ solo lo puede suscribir un ADMIN y
 * un broker caido no corta el latido del pasajero.
 */
@Component
@RequiredArgsConstructor
public class PasajeroUbicacionPublisher {

    private static final Logger LOG = LoggerFactory.getLogger(PasajeroUbicacionPublisher.class);
    static final String TOPIC_ADMIN = "/topic/admin/pasajeros";

    private final SimpMessagingTemplate simpMessagingTemplate;

    public void publicar(PasajeroEnLineaResponse mensaje) {
        try {
            simpMessagingTemplate.convertAndSend(TOPIC_ADMIN, mensaje);
        } catch (Exception excepcion) {
            LOG.warn("No se pudo publicar la posicion del pasajero {} por WebSocket",
                    mensaje.idPasajero(), excepcion);
        }
    }
}
