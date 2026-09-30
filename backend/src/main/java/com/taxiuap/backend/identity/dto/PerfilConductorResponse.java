package com.taxiuap.backend.identity.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.vehicle.enums.TipoDocumento;

/**
 * Datos del perfil de un conductor: persona, usuario, licencia, aprobacion, billetera y los
 * documentos obligatorios que todavia no envio (la app queda bloqueada mientras falte alguno).
 */
public record PerfilConductorResponse(
        Long idConductor,
        String nombres,
        String apellidos,
        String ci,
        String complementoCi,
        LocalDate fechaNacimiento,
        String correo,
        String telefono,
        String fotoUrl,
        String numeroLicencia,
        String categoriaLicencia,
        SituacionAprobacion situacionAprobacion,
        BigDecimal calificacionPromedio,
        Integer totalCalificaciones,
        LocalDateTime fechaAprobacion,
        BigDecimal saldoBilletera,
        Long idUsuario,
        List<TipoDocumento> documentosFaltantes) {
}
