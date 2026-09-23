package com.taxiuap.backend.identity.dto;

import com.taxiuap.backend.identity.enums.TipoRegistroUsuario;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Cuentas que el administrador habilita para una persona ya registrada.
 *
 * nombreUsuario y password son obligatorios salvo cuando la persona ya tiene una cuenta de
 * pasajero o conductor y se agrega la otra: en ese caso se reutilizan sus credenciales. conductor
 * es obligatorio si el tipo incluye conductor.
 */
public record HabilitarUsuarioRequest(
        @NotNull TipoRegistroUsuario tipo,
        @Pattern(regexp = NombreUsuario.PATRON, message = NombreUsuario.MENSAJE) String nombreUsuario,
        @Size(min = 8, max = 72) String password,
        @Size(max = 100) String cargo,
        @Valid DatosConductorRequest conductor) {
}
