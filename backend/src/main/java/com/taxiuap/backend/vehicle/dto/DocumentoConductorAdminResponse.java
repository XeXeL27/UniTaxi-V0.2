package com.taxiuap.backend.vehicle.dto;

import java.time.LocalDate;

import com.taxiuap.backend.vehicle.enums.SituacionRevision;
import com.taxiuap.backend.vehicle.enums.TipoDocumento;

/** Datos de un documento de conductor para revision administrativa. */
public record DocumentoConductorAdminResponse(
        Long id,
        Long idConductor,
        String nombresConductor,
        String apellidosConductor,
        Long idVehiculo,
        TipoDocumento tipoDocumento,
        String archivoUrl,
        LocalDate fechaVencimiento,
        SituacionRevision situacionRevision,
        Long idAdminRevisor) {
}
