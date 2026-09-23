package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Size;

/** Datos para registrar o actualizar una persona. */
public record PersonaRequest(
        @Size(max = 30) String ci,
        @Size(max = 10) String complementoCi,
        @NotBlank @Size(max = 100) String nombres,
        @NotBlank @Size(max = 100) String apellidos,
        @Past LocalDate fechaNacimiento,
        @Email @Size(max = 150) String correo,
        @Size(max = 20) String telefono) {
}
