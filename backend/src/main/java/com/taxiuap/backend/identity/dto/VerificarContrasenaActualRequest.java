package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;

/** Perfil > Cambiar contrasena, paso 2 con la contrasena actual: se revisa antes de pedir la nueva. */
public record VerificarContrasenaActualRequest(@NotBlank String actual) {
}
