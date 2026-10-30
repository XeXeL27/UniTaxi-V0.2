package com.taxiuap.backend.trip.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/** "ACEPTO EL COSTO TOTAL": la version exacta que el cliente vio. Si cambio, el servidor responde 409. */
public record AceptarCostoRequest(
        @NotNull(message = "Falta la version del costo") @Min(1) Integer version) {
}
