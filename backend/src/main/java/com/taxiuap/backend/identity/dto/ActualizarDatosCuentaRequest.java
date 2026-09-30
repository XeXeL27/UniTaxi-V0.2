package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Cambio de datos desde Mi perfil de la app: solo el correo y el telefono (y la licencia del
 * conductor mientras este en blanco). No se aplica de inmediato: se envia un codigo al correo
 * actual y se confirma con {@link ConfirmarDatosCuentaRequest}.
 */
public record ActualizarDatosCuentaRequest(
        @NotBlank @Email @Size(max = 150) String correo,
        @Size(max = 20) String telefono,
        @Size(max = 30) String numeroLicencia,
        @Size(max = 10) String categoriaLicencia) {
}
