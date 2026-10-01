package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Motivo con que el administrador rechaza los datos de un carnet observado (le llega por correo). */
public record RechazoCarnetRequest(@NotBlank @Size(max = 250) String motivo) {
}
