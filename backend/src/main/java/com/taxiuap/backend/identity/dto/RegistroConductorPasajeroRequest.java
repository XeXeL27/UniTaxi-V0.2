package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Pasajero que se registra como conductor desde Mas. Nombre y correo ya los tiene; aqui completa lo
 * que el pasajero no dio (CI, telefono, fecha de nacimiento) y lo del conductor. Los PDF y los QR van
 * como partes del multipart.
 */
public record RegistroConductorPasajeroRequest(
        @NotBlank @Pattern(regexp = ReglasRegistro.PATRON_CI, message = ReglasRegistro.MENSAJE_CI) String ci,
        @Pattern(regexp = ReglasRegistro.PATRON_COMPLEMENTO, message = ReglasRegistro.MENSAJE_COMPLEMENTO) String complementoCi,
        @NotNull @Past LocalDate fechaNacimiento,
        @NotBlank @Pattern(regexp = ReglasRegistro.PATRON_CELULAR, message = ReglasRegistro.MENSAJE_CELULAR) String telefono,
        /** Nombres y apellidos leidos del carnet (mandan sobre los de Google); opcionales. */
        @Size(max = 100) @Pattern(regexp = ReglasRegistro.PATRON_NOMBRE, message = ReglasRegistro.MENSAJE_NOMBRE) String nombres,
        @Size(max = 100) @Pattern(regexp = ReglasRegistro.PATRON_NOMBRE, message = ReglasRegistro.MENSAJE_NOMBRE) String apellidos,
        @Valid @NotNull DatosConductorRequest conductor,
        /** true: la persona indico que sus datos se leyeron mal; un administrador los revisa (OBSERVADO). */
        Boolean observado,
        /** true: marco que acepta los terminos y condiciones (obligatorio al enviar el carnet). */
        Boolean aceptaTerminos) {

    public boolean esObservado() {
        return Boolean.TRUE.equals(observado);
    }

    public boolean aceptoTerminos() {
        return Boolean.TRUE.equals(aceptaTerminos);
    }
}
