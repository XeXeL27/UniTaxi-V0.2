package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.Pattern;

/** Guia vista: el codigo de la guia de una parte de la app (null = la guia de inicio). */
public record GuiaVistaRequest(
        @Pattern(regexp = "^[A-Z_]{3,40}$", message = "Codigo de guia no valido") String guia) {
}
