package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Contrasena nueva despues de verificar el codigo de recuperacion. */
public record CambiarContrasenaRecuperacionRequest(
        @NotBlank String recuperacion,
        @NotBlank @Size(min = 8, max = 72, message = ReglasRegistro.MENSAJE_CONTRASENA) String nueva,
        @NotBlank String confirmacion) {
}
