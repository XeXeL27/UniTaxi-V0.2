package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Size;

/**
 * Datos del carnet que la app lee de las fotos (anverso y reverso) y la persona confirma: numero,
 * complemento (lo que va despues del guion) y fecha de nacimiento.
 */
public record CarnetRequest(
        @NotBlank @Size(max = 30) String ci,
        @Size(max = 10) String complementoCi,
        @NotNull @Past LocalDate fechaNacimiento) {
}
