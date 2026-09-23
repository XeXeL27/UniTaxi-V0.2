package com.taxiuap.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Datos de inicio de sesion. El campo usuario acepta nombre de usuario, correo o telefono.
 * El rol es opcional: se necesita cuando la persona tiene cuenta de pasajero y de conductor con
 * las mismas credenciales (cada app envia el rol con que entra; el panel admin envia ADMIN).
 */
public record LoginRequest(
        @NotBlank String usuario,
        @NotBlank String password,
        String rol) {
}
