package com.taxiuap.backend.trip.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

import com.taxiuap.backend.trip.dto.OfertaViajeResponse;
import com.taxiuap.backend.trip.dto.SolicitudViajeResponse;

import lombok.RequiredArgsConstructor;

/**
 * Punto unico de publicacion por WebSocket del flujo de solicitud y oferta de viaje, inspirado en
 * PuestoEventPublisher de uniFex.
 *
 * Todas las publicaciones se envuelven en try/catch: un fallo al enviar por WebSocket (por
 * ejemplo, el broker STOMP caido) nunca debe tumbar la transaccion de negocio que ya escribio en
 * la base de datos. En el peor caso el cliente no se entera en tiempo real y lo descubre al
 * refrescar via REST.
 */
@Component
@RequiredArgsConstructor
public class ViajeEventPublisher {

    private static final Logger LOG = LoggerFactory.getLogger(ViajeEventPublisher.class);

    private final SimpMessagingTemplate simpMessagingTemplate;

    /** Avisa a los conductores habilitados que hay una nueva solicitud disponible. */
    public void publicarSolicitudNueva(SolicitudViajeResponse solicitud) {
        try {
            simpMessagingTemplate.convertAndSend("/topic/solicitudes", solicitud);
        } catch (Exception excepcion) {
            LOG.warn("No se pudo publicar la solicitud nueva {} por WebSocket", solicitud.idSolicitud(), excepcion);
        }
    }

    /** Avisa al pasajero dueno de la solicitud que recibio una nueva oferta. */
    public void publicarOfertaNueva(Long idUsuarioPasajero, OfertaViajeResponse oferta) {
        try {
            simpMessagingTemplate.convertAndSendToUser(String.valueOf(idUsuarioPasajero), "/queue/ofertas", oferta);
        } catch (Exception excepcion) {
            LOG.warn("No se pudo publicar la oferta nueva {} al usuario {} por WebSocket",
                    oferta.idOferta(), idUsuarioPasajero, excepcion);
        }
    }

    /** Avisa que una solicitud ya no admite ofertas (aceptada o cancelada). */
    public void publicarSolicitudCerrada(Long idSolicitud, String motivo) {
        try {
            simpMessagingTemplate.convertAndSend("/topic/solicitudes",
                    new SolicitudCerrada(idSolicitud, motivo));
        } catch (Exception excepcion) {
            LOG.warn("No se pudo publicar el cierre de la solicitud {} por WebSocket", idSolicitud, excepcion);
        }
    }

    /** Payload minimo para avisar que una solicitud se cerro y por que. */
    private record SolicitudCerrada(Long idSolicitud, String motivo) {
    }
}
