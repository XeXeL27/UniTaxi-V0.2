package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Size;

/**
 * Datos del carnet que la app lee de las fotos (anverso y reverso) y la persona confirma: numero,
 * complemento (lo que va despues del guion, solo si el carnet lo tiene), fecha de nacimiento y el
 * nombre impreso en el carnet, que reemplaza al de la cuenta (el de Google puede ser un apodo).
 * password: solo cuando el conductor cambia las fotos con permiso del administrador.
 */
public record CarnetRequest(
        @NotBlank @Pattern(regexp = ReglasRegistro.PATRON_CI, message = ReglasRegistro.MENSAJE_CI) String ci,
        @Pattern(regexp = ReglasRegistro.PATRON_COMPLEMENTO, message = ReglasRegistro.MENSAJE_COMPLEMENTO) String complementoCi,
        @NotNull @Past LocalDate fechaNacimiento,
        /** Nombres y apellidos leidos del carnet (mandan sobre los de Google); opcionales. */
        @Size(max = 100) @Pattern(regexp = ReglasRegistro.PATRON_NOMBRE, message = ReglasRegistro.MENSAJE_NOMBRE) String nombres,
        @Size(max = 100) @Pattern(regexp = ReglasRegistro.PATRON_NOMBRE, message = ReglasRegistro.MENSAJE_NOMBRE) String apellidos,
        String password) {
}
