package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Mensaje al administrador cuando los codigos por correo no alcanzaron: el problema y un celular. */
public record MensajeAyudaIngresoRequest(
        @NotBlank String recuperacion,
        @NotBlank @Size(min = 10, max = 1000, message = "Describe el problema (de 10 a 1000 caracteres)")
        String descripcion,
        @NotBlank @Pattern(regexp = ReglasRegistro.PATRON_CELULAR, message = ReglasRegistro.MENSAJE_CELULAR)
        String celular) {
}
