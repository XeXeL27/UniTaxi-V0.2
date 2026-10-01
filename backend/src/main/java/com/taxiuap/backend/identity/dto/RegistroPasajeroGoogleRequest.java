package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Fin del registro de pasajero con Google: el codigo temporal del ingreso y los datos del carnet que
 * la persona confirmo (los mismos de CarnetRequest). Las fotos van en las partes "anverso" y "reverso".
 */
public record RegistroPasajeroGoogleRequest(
        @NotBlank String codigo,
        @NotBlank @Pattern(regexp = ReglasRegistro.PATRON_CI, message = ReglasRegistro.MENSAJE_CI) String ci,
        @Pattern(regexp = ReglasRegistro.PATRON_COMPLEMENTO, message = ReglasRegistro.MENSAJE_COMPLEMENTO) String complementoCi,
        @NotNull @Past LocalDate fechaNacimiento,
        @Size(max = 100) @Pattern(regexp = ReglasRegistro.PATRON_NOMBRE, message = ReglasRegistro.MENSAJE_NOMBRE) String nombres,
        @Size(max = 100) @Pattern(regexp = ReglasRegistro.PATRON_NOMBRE, message = ReglasRegistro.MENSAJE_NOMBRE) String apellidos,
        /** true: la persona indico que sus datos se leyeron mal; un administrador los revisa (OBSERVADO). */
        Boolean observado) {

    public CarnetRequest carnet() {
        return new CarnetRequest(ci, complementoCi, fechaNacimiento, nombres, apellidos, null, observado);
    }
}
