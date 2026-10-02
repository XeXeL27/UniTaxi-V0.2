package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Edicion completa de una cuenta desde Usuarios del panel: datos de la persona, nombre de usuario y,
 * si la persona es conductor, su licencia. Las fotos del carnet y de la licencia van como partes
 * aparte del multipart.
 */
public record EdicionUsuarioAdminRequest(
        @Size(max = 30) String ci,
        @Size(max = 10) String complementoCi,
        @NotBlank @Size(max = 100) String nombres,
        @NotBlank @Size(max = 100) String apellidos,
        @Past LocalDate fechaNacimiento,
        @Email @Size(max = 150) String correo,
        @Size(max = 20) String telefono,
        @NotBlank @Pattern(regexp = NombreUsuario.PATRON, message = NombreUsuario.MENSAJE) String nombreUsuario,
        /** Solo si la persona tiene cuenta de conductor; vacio = no se cambia la licencia. */
        @Size(max = 30) String numeroLicencia,
        @Pattern(regexp = ReglasRegistro.PATRON_CATEGORIA, message = ReglasRegistro.MENSAJE_CATEGORIA) String categoriaLicencia,
        LocalDate vencimientoLicencia) {
}
