package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Datos para el registro publico de un pasajero. Correo y telefono son opcionales por separado,
 * pero el servicio exige que al menos uno este presente.
 */
public record RegistroPasajeroRequest(
        String ci,
        String complementoCi,
        @NotBlank String nombres,
        @NotBlank String apellidos,
        LocalDate fechaNacimiento,
        @Email String correo,
        String telefono,
        @NotBlank @Pattern(regexp = NombreUsuario.PATRON, message = NombreUsuario.MENSAJE) String nombreUsuario,
        @NotBlank @Size(min = 8, max = 72) String password) {
}
