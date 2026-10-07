package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Cambio de contrasena desde la app: la actual, la nueva y su confirmacion. */
public record CambiarContrasenaRequest(
        @NotBlank String actual,
        @NotBlank @Size(min = 8, max = 72, message = ReglasRegistro.MENSAJE_CONTRASENA) String nueva,
        @NotBlank String confirmacion) {
}
