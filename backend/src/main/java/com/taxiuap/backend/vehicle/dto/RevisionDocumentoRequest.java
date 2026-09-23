package com.taxiuap.backend.vehicle.dto;

import com.taxiuap.backend.vehicle.enums.SituacionRevision;

import jakarta.validation.constraints.NotNull;

/** Datos para que un administrador revise un documento de conductor. */
public record RevisionDocumentoRequest(
        @NotNull SituacionRevision situacion,
        String motivo) {
}
