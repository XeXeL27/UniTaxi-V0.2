package com.taxiuap.backend.communication.dto;

import com.taxiuap.backend.communication.enums.SituacionAyudaIngreso;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** El administrador cierra el mensaje: ATENDIDA o DESCARTADA, con lo que hizo. */
public record AtenderAyudaIngresoRequest(
        @NotNull SituacionAyudaIngreso situacion,
        @NotBlank @Size(max = 1000) String observacion) {
}
