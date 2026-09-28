package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.NotBlank;

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
        String categoriaLicencia) {
}
