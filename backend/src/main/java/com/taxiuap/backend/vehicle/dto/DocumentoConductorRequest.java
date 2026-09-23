package com.taxiuap.backend.vehicle.dto;

import java.time.LocalDate;

import com.taxiuap.backend.vehicle.enums.TipoDocumento;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/** Datos de entrada para subir o reemplazar un documento del conductor autenticado. */
public record DocumentoConductorRequest(
        @NotNull TipoDocumento tipoDocumento,
        Long idVehiculo,
        @NotBlank String archivoUrl,
        LocalDate fechaVencimiento) {
}
