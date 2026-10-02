package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Todo lo de una cuenta para el modal "Editar" de Usuarios del panel: datos de la persona, si tiene
 * las fotos del carnet y, si la cuenta es de conductor (o la persona tiene una), su licencia.
 */
public record UsuarioDetalleAdminResponse(
        Long idUsuario,
        Long idPersona,
        String nombreUsuario,
        String rol,
        String situacion,
        String ci,
        String complementoCi,
        String nombres,
        String apellidos,
        LocalDate fechaNacimiento,
        String correo,
        String telefono,
        boolean carnetAnverso,
        boolean carnetReverso,
        String situacionCarnet,
        LocalDateTime fechaAceptaTerminos,
        /** null si la persona no tiene cuenta de conductor. */
        Long idConductor,
        String numeroLicencia,
        String categoriaLicencia,
        LocalDate vencimientoLicencia,
        boolean licenciaAnverso,
        boolean licenciaReverso) {
}
