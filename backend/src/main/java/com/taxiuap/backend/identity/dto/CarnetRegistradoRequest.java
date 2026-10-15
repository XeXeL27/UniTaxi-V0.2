package com.taxiuap.backend.identity.dto;

import com.taxiuap.backend.communication.enums.OrigenAyudaIngreso;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

/** El formulario de registro pregunta si el carnet ya es de alguien registrado en UNITAXI. */
public record CarnetRegistradoRequest(
        @NotBlank @Pattern(regexp = ReglasRegistro.PATRON_CI, message = ReglasRegistro.MENSAJE_CI) String ci,
        String complementoCi,
        @NotNull OrigenAyudaIngreso origen) {
}
