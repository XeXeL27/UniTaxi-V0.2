package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Size;

/**
 * Pasajero que se registra como conductor desde Mas. Nombre y correo ya los tiene; aqui completa lo
 * que el pasajero no dio (CI, telefono, fecha de nacimiento) y lo del conductor. Los PDF y los QR van
 * como partes del multipart.
 */
public record RegistroConductorPasajeroRequest(
        @NotBlank @Size(max = 30) String ci,
        @Size(max = 10) String complementoCi,
        @NotNull @Past LocalDate fechaNacimiento,
        @NotBlank @Size(max = 20) String telefono,
        @Valid @NotNull DatosConductorRequest conductor) {
}
