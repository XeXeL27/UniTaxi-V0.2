package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

/**
 * Datos con que la app llena el formulario de conductor: nombre y correo de Google (no se cambian
 * ahi) y, si la persona ya estaba registrada (por ejemplo como pasajero), lo que ya se sabia de ella.
 */
public record PerfilGoogleResponse(
        String correo,
        String nombres,
        String apellidos,
        String ci,
        String complementoCi,
        String telefono,
        LocalDate fechaNacimiento) {
}
