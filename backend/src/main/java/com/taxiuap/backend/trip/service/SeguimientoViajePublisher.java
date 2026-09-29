package com.taxiuap.backend.trip.service;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

import com.taxiuap.backend.location.dto.PosicionConductorMensaje;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.repository.ViajeRepository;

import lombok.RequiredArgsConstructor;

/**
 * Publica la posicion del conductor al pasajero de su viaje activo, para que el pasajero vea en
 * tiempo real de donde viene el conductor, a que distancia esta y cuanto tarda en llegar.
 *
 * Solo se publica cuando el conductor tiene un viaje activo (no finalizado ni cancelado). El
 * destino es la cola por usuario del pasajero (/user/queue/conductor-ubicacion), asi que solo ese
 * pasajero recibe el mensaje.
 */
@Component
@RequiredArgsConstructor
public class SeguimientoViajePublisher {

    private static final Logger LOG = LoggerFactory.getLogger(SeguimientoViajePublisher.class);
    private static final List<SituacionViaje> ESTADOS_FINALES =
            List.of(SituacionViaje.COMPLETADO, SituacionViaje.CANCELADO);

    private final SimpMessagingTemplate simpMessagingTemplate;
    private final ViajeRepository viajeRepository;

    /**
     * Si el conductor tiene un viaje activo, envia su posicion al pasajero de ese viaje.
     * Un fallo de WebSocket nunca debe tumbar la transaccion del reporte de posicion.
     */
    public void publicarAlPasajero(PosicionConductorMensaje mensaje) {
        try {
            viajeRepository.findFirstByConductorIdAndSituacionViajeNotIn(mensaje.idConductor(), ESTADOS_FINALES)
                    .ifPresent(viaje -> simpMessagingTemplate.convertAndSendToUser(
                            String.valueOf(viaje.getPasajero().getUsuario().getId()),
                            "/queue/conductor-ubicacion",
                            mensaje));
        } catch (Exception excepcion) {
            LOG.warn("No se pudo publicar la posicion del conductor {} al pasajero de su viaje activo",
                    mensaje.idConductor(), excepcion);
        }
    }
}
