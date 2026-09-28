package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Registro publico de conductor con el formulario (sin Google): datos de la persona, la cuenta, la
 * licencia y la moto. Los PDF (CI y LICENCIA obligatorios) viajan como partes del multipart.
 */
public record RegistroConductorRequest(
        @NotBlank @Size(max = 30) String ci,
        @Size(max = 10) String complementoCi,
        @NotBlank @Size(max = 100) String nombres,
        @NotBlank @Size(max = 100) String apellidos,
        @Past LocalDate fechaNacimiento,
        @NotBlank @Email @Size(max = 150) String correo,
        @NotBlank @Size(max = 20) String telefono,
        @NotBlank @Pattern(regexp = NombreUsuario.PATRON, message = NombreUsuario.MENSAJE) String nombreUsuario,
        @NotBlank @Size(min = 8, max = 72) String password,
        @Valid @NotNull DatosConductorRequest conductor) {
}
