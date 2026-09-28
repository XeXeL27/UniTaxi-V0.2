package com.taxiuap.backend.sistema.dto;

import jakarta.validation.constraints.NotBlank;

/** Ruta absoluta de una carpeta del servidor. */
public record RutaCarpetaRequest(@NotBlank String ruta) {
}
