package com.taxiuap.backend.identity.dto;

import java.time.LocalDateTime;

/** Fila de Personas > Eliminacion permanente: la persona y sus cuentas (activas o ya eliminadas). */
public record PersonaEliminableResponse(
        Long idPersona,
        String nombres,
        String apellidos,
        String ci,
        String correo,
        String telefono,
        /** Tipos de cuenta, por ejemplo "PASAJERO, CONDUCTOR"; vacio si no tiene. */
        String cuentas,
        /** ACTIVA o ELIMINADA (borrado logico previo). */
        String estado,
        LocalDateTime registrado) {
}
