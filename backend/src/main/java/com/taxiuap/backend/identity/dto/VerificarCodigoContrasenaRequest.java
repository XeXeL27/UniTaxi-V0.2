package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/** Perfil > Cambiar contrasena, paso 2 con el codigo que llego al correo registrado (6 digitos). */
public record VerificarCodigoContrasenaRequest(
        @NotBlank @Pattern(regexp = "\\s*\\d{6}\\s*", message = "El código tiene 6 números") String codigo) {
}
