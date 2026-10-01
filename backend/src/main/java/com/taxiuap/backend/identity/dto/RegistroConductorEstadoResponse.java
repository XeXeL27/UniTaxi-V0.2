package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

import com.taxiuap.backend.identity.enums.SituacionAprobacion;

/**
 * Registro de conductor del pasajero autenticado: su situacion (null si todavia no se registro) y los
 * datos con que se precarga el formulario.
 */
public record RegistroConductorEstadoResponse(
        SituacionAprobacion situacion,
        String correo,
        String nombres,
        String apellidos,
        String ci,
        String complementoCi,
        String telefono,
        LocalDate fechaNacimiento,
        /** Ya registro las fotos de su carnet: el formulario no las vuelve a pedir ni cambia el CI. */
        boolean tieneCarnet) {
}
