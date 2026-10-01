package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Cambio de datos desde Mi perfil de la app: solo el correo y el telefono (y la licencia del
 * conductor mientras este en blanco). Se confirma con la contrasena de la cuenta.
 */
public record ActualizarDatosCuentaRequest(
        @NotBlank @Email @Size(max = 150) String correo,
        @Size(max = 20) String telefono,
        @Size(max = 30) String numeroLicencia,
        @Pattern(regexp = ReglasRegistro.PATRON_CATEGORIA, message = ReglasRegistro.MENSAJE_CATEGORIA) String categoriaLicencia,
        String password) {
}
