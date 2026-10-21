package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import com.taxiuap.backend.identity.enums.TipoRegistroPersona;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Persona que el administrador registra desde el panel con su cuenta de pasajero. Los datos van escritos;
 * las fotos del carnet son opcionales (si faltan, la persona las sube al ingresar por primera vez).
 * ru: solo para ESTUDIANTE_UAP. carnetVencimiento: opcional (lo que dice "Valida hasta").
 */
public record RegistroPersonaAdminRequest(
        @NotNull(message = "Elige si es persona externa o estudiante U.A.P.") TipoRegistroPersona tipo,
        @Size(max = 20) String ru,
        @NotBlank(message = "Escribe el número de carnet") @Pattern(regexp = "^\\d{4,12}$",
                message = "El carnet solo lleva números (de 4 a 12)") String ci,
        @Size(max = 10) String complementoCi,
        @NotBlank @Size(max = 100) String nombres,
        @NotBlank @Size(max = 100) String apellidos,
        @NotNull(message = "Escribe la fecha de nacimiento") @Past LocalDate fechaNacimiento,
        @NotBlank(message = "Escribe el correo: ahí le llegan sus credenciales") @Email @Size(max = 150) String correo,
        @NotBlank @Pattern(regexp = ReglasRegistro.PATRON_CELULAR, message = ReglasRegistro.MENSAJE_CELULAR)
        String telefono,
        LocalDate carnetVencimiento) {
}
