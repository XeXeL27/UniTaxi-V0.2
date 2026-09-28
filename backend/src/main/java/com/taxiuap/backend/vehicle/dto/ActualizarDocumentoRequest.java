package com.taxiuap.backend.vehicle.dto;

import java.time.LocalDate;

import com.taxiuap.backend.vehicle.enums.TipoDocumento;

import jakarta.validation.constraints.NotNull;

/** Datos del documento que corrige el administrador (el PDF se reemplaza aparte). */
public record ActualizarDocumentoRequest(
        @NotNull TipoDocumento tipoDocumento,
        LocalDate fechaVencimiento) {
}
