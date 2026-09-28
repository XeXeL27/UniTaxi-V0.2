package com.taxiuap.backend.sistema.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Carpeta nueva dentro de [padre]. */
public record CrearCarpetaRequest(
        @NotBlank String padre,
        @NotBlank @Size(max = 80) String nombre) {
}
