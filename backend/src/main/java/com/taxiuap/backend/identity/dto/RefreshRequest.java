package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;

/** Solicitud de renovacion de tokens a partir de un token de refresco vigente. */
public record RefreshRequest(
        @NotBlank String tokenRefresco) {
}
