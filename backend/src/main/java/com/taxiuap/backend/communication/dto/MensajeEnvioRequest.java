package com.taxiuap.backend.communication.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Datos de entrada para enviar un mensaje de chat dentro de un viaje. */
public record MensajeEnvioRequest(
        @NotNull Long idViaje,
        @NotBlank @Size(max = 500) String contenido) {
}
