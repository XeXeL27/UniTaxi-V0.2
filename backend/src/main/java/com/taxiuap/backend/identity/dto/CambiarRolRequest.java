package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;

/** Rol al que se cambia la sesion: PASAJERO o CONDUCTOR. */
public record CambiarRolRequest(@NotBlank String rol) {
}
