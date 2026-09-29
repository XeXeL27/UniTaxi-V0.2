package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Size;

/**
 * Datos que el pasajero o el conductor cambia desde Mi perfil. Se confirma con la contrasena de la
 * cuenta. La licencia solo se usa (y es obligatoria) en la cuenta de conductor.
 */
public record ActualizarDatosCuentaRequest(
        @NotBlank String password,
        @NotBlank @Size(max = 100) String nombres,
        @NotBlank @Size(max = 100) String apellidos,
        @Size(max = 30) String ci,
        @Size(max = 10) String complementoCi,
        @Past LocalDate fechaNacimiento,
        @NotBlank @Email @Size(max = 150) String correo,
        @Size(max = 20) String telefono,
        @Size(max = 30) String numeroLicencia,
        @Size(max = 10) String categoriaLicencia) {
}
