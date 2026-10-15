package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/** El codigo que llego al correo registrado. */
public record VerificarCodigoRecuperacionRequest(
        @NotBlank String recuperacion,
        @NotBlank @Pattern(regexp = "\\d{6}", message = "El codigo tiene 6 digitos") String codigo) {
}
