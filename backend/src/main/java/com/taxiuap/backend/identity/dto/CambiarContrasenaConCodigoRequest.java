package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Cambio de contrasena desde el perfil sin la actual: el codigo del correo, la nueva y su confirmacion. */
public record CambiarContrasenaConCodigoRequest(
        @NotBlank @Pattern(regexp = "\\s*\\d{6}\\s*", message = "El código tiene 6 números") String codigo,
        @NotBlank @Size(min = 8, max = 72, message = ReglasRegistro.MENSAJE_CONTRASENA) String nueva,
        @NotBlank String confirmacion) {
}
