package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Size;

/**
 * Registro de conductor despues de elegir la cuenta de Google. Nombre y correo vienen de Google
 * (por [codigo]); aqui va lo que Google no sabe. Los PDF viajan como partes del multipart.
 */
public record RegistroConductorGoogleRequest(
        @NotBlank String codigo,
        @NotBlank @Size(max = 30) String ci,
        @Size(max = 10) String complementoCi,
        @Past LocalDate fechaNacimiento,
        @NotBlank @Size(max = 20) String telefono,
        @Valid @NotNull DatosConductorRequest conductor) {
}
