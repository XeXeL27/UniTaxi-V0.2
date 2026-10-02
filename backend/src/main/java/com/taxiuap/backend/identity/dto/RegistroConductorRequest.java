package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Registro publico de conductor con el formulario (sin Google): datos de la persona, la cuenta, la
 * licencia y la moto. Los PDF viajan como partes del multipart; si falta el CI o la licencia el
 * registro se acepta igual y la app queda bloqueada hasta que los suba (Mis documentos).
 */
public record RegistroConductorRequest(
        @NotBlank @Pattern(regexp = ReglasRegistro.PATRON_CI, message = ReglasRegistro.MENSAJE_CI) String ci,
        @Pattern(regexp = ReglasRegistro.PATRON_COMPLEMENTO, message = ReglasRegistro.MENSAJE_COMPLEMENTO) String complementoCi,
        @NotBlank @Size(max = 100) String nombres,
        @NotBlank @Size(max = 100) String apellidos,
        @Past LocalDate fechaNacimiento,
        @NotBlank @Email @Size(max = 150) String correo,
        @NotBlank @Pattern(regexp = ReglasRegistro.PATRON_CELULAR, message = ReglasRegistro.MENSAJE_CELULAR) String telefono,
        @NotBlank @Pattern(regexp = NombreUsuario.PATRON, message = NombreUsuario.MENSAJE) String nombreUsuario,
        @NotBlank @Size(min = 8, max = 72) String password,
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
