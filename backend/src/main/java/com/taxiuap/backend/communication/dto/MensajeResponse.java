package com.taxiuap.backend.communication.dto;

import java.time.LocalDateTime;

/** Datos de salida de un mensaje de chat. */
public record MensajeResponse(
        Long idMensaje,
        Long idViaje,
        Long idUsuarioEmisor,
        String nombreEmisor,
        String contenido,
        boolean leido,
        LocalDateTime fecha) {
}
