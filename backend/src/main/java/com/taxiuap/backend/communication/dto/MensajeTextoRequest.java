package com.taxiuap.backend.communication.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Texto de un mensaje de chat enviado por REST (el viaje va en la ruta). */
public record MensajeTextoRequest(@NotBlank @Size(max = 500) String contenido) {
}
