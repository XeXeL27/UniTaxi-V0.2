package com.taxiuap.backend.trip.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * Codigo de 8 digitos que dicta una de las partes para validar la recogida en A o la entrega en B. El
 * repartidor lo digita, nunca lo recibe de la API.
 */
public record ValidarCodigoEntregaRequest(
        @NotBlank(message = "El codigo es obligatorio")
        @Pattern(regexp = "\\d{8}", message = "El codigo debe tener 8 digitos")
        String codigo) {
}
