package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Correo de una persona que todavia no lo tiene (cuentas creadas sin correo). */
public record CompletarCorreoRequest(@NotBlank @Email @Size(max = 150) String correo) {
}
