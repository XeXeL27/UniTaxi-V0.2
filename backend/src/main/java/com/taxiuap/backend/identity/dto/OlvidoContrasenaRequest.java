package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/** Pedido del codigo para restablecer la contrasena: llega al correo de la persona. */
public record OlvidoContrasenaRequest(@NotBlank @Email String correo) {
}
