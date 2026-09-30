package com.taxiuap.backend.identity.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.taxiuap.backend.identity.enums.SituacionAprobacion;

/** Datos de un conductor para revision administrativa. */
public record ConductorAdminResponse(
        Long idConductor,
        Long idPersona,
        String nombreUsuario,
        String nombres,
        String apellidos,
        String ci,
        String correo,
        String telefono,
        String numeroLicencia,
        String categoriaLicencia,
        String placa,
        SituacionAprobacion situacionAprobacion,
        BigDecimal calificacionPromedio,
        Integer totalCalificaciones,
        LocalDateTime fechaAprobacion,
        long cantidadDocumentos,
        /** Cuenta del conductor (para eliminarla desde el panel). */
        Long idUsuario) {
}
