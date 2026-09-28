package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;

/** Codigo de un solo uso con que la app recoge la sesion al volver de Google. */
public record CanjeGoogleRequest(@NotBlank String codigo) {
}
