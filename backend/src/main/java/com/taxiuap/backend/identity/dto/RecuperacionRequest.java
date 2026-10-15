package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;

/** Pedido de un codigo para la recuperacion de cuenta en curso. */
public record RecuperacionRequest(@NotBlank String recuperacion) {
}
