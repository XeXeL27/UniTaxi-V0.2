package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Codigo recibido por correo y la contrasena nueva con su confirmacion. */
public record RestablecerContrasenaRequest(
        @NotBlank @Email String correo,
        @NotBlank @Pattern(regexp = "\\d{6}", message = "El codigo tiene 6 digitos") String codigo,
        @NotBlank @Size(min = 8, max = 72) String nueva,
        @NotBlank String confirmacion) {
}
