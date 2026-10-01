package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Datos de la licencia leidos de sus fotos (o corregidos por el administrador): numero, categoria
 * (una letra: P, M, A, B o C) y vencimiento. password: solo cuando el conductor cambia las fotos
 * con permiso del administrador.
 */
public record LicenciaRequest(
        @NotBlank @Size(max = 30) String numeroLicencia,
        @Pattern(regexp = ReglasRegistro.PATRON_CATEGORIA, message = ReglasRegistro.MENSAJE_CATEGORIA) String categoriaLicencia,
        LocalDate vencimientoLicencia,
        String password) {
}
