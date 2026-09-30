package com.taxiuap.backend.identity.dto;

import com.taxiuap.backend.shared.enums.EstadoRegistro;

import jakarta.validation.constraints.NotNull;

/** Suspender (S) o volver a habilitar (A) una cuenta desde el panel. */
public record CambiarEstadoUsuarioRequest(@NotNull EstadoRegistro estado) {
}
