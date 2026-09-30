package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Codigo de 6 digitos enviado al correo actual para aplicar el cambio de datos de Mi perfil. */
public record ConfirmarDatosCuentaRequest(@NotBlank @Size(max = 10) String codigo) {
}
