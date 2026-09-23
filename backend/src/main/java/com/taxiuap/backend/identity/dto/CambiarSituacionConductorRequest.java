package com.taxiuap.backend.identity.dto;

import com.taxiuap.backend.identity.enums.SituacionAprobacion;

import jakarta.validation.constraints.NotNull;

/** Datos para que un administrador cambie la situacion de aprobacion de un conductor. */
public record CambiarSituacionConductorRequest(
        @NotNull SituacionAprobacion situacion,
        String motivo) {
}
