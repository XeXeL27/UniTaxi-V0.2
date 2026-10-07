package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Datos del carnet que el administrador reviso (y corrigio si hacia falta) mirando las fotos.
 * aprobarConductor: si la persona es conductor, su cuenta de conductor tambien queda APROBADA.
 * comoEstudiante: si se registro como estudiante UAP, true lo aprueba como estudiante (con descuento) y
 * false como pasajero normal (null cuenta como true).
 */
public record RevisionCarnetRequest(
        @NotBlank @Pattern(regexp = ReglasRegistro.PATRON_CI, message = ReglasRegistro.MENSAJE_CI) String ci,
        @Pattern(regexp = ReglasRegistro.PATRON_COMPLEMENTO, message = ReglasRegistro.MENSAJE_COMPLEMENTO) String complementoCi,
        @NotBlank @Size(max = 100) @Pattern(regexp = ReglasRegistro.PATRON_NOMBRE, message = ReglasRegistro.MENSAJE_NOMBRE) String nombres,
        @NotBlank @Size(max = 100) @Pattern(regexp = ReglasRegistro.PATRON_NOMBRE, message = ReglasRegistro.MENSAJE_NOMBRE) String apellidos,
        @NotNull @Past LocalDate fechaNacimiento,
        Boolean aprobarConductor,
        Boolean comoEstudiante,
        /** "Valida hasta" del carnet segun la foto (opcional: el servidor no siempre lo pudo leer). */
        LocalDate carnetVencimiento) {
}
