package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;
import java.math.BigDecimal;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Pattern;

/**
 * Datos editables del perfil de un conductor. La situacion de aprobacion no se incluye: solo un
 * administrador la puede cambiar (ver GestionConductorService).
 */
public record ActualizarPerfilConductorRequest(
        @NotBlank String nombres,
        @NotBlank String apellidos,
        String ci,
        String complementoCi,
        LocalDate fechaNacimiento,
        @NotBlank String numeroLicencia,
        @Pattern(regexp = ReglasRegistro.PATRON_CATEGORIA, message = ReglasRegistro.MENSAJE_CATEGORIA) String categoriaLicencia,
        @DecimalMin(value = "0.00") BigDecimal limiteAdelantoCompra,
        /** Contrasena de la cuenta: todo cambio se confirma con ella (o con la huella en la app). */
        String password) {
}
