package com.taxiuap.backend.trip.service;

import java.time.LocalDateTime;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.trip.entity.HistorialEstadoViaje;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.repository.HistorialEstadoViajeRepository;

import lombok.RequiredArgsConstructor;

/**
 * Registra el historial de cambios de situacion de un viaje. Regla de negocio 6: cada cambio de
 * situacion_viaje se registra en historial_estado_viaje, incluida el alta del viaje.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class HistorialViajeService {

    private final HistorialEstadoViajeRepository historialEstadoViajeRepository;
    private final UsuarioRepository usuarioRepository;

    /** Crea una fila de historial con la situacion actual del viaje y quien hizo el cambio. */
    @Transactional
    public void registrar(Viaje viaje, SituacionViaje situacion, Long idUsuarioCambio) {
        HistorialEstadoViaje historial = new HistorialEstadoViaje();
        historial.setViaje(viaje);
        historial.setUsuarioCambio(usuarioRepository.findById(idUsuarioCambio)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", idUsuarioCambio)));
        historial.setSituacionViaje(situacion);
        historial.setFecha(LocalDateTime.now());
        historialEstadoViajeRepository.save(historial);
    }
}
