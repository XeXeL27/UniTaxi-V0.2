package com.taxiuap.backend.vehicle.dto;

import java.time.LocalDate;

import com.taxiuap.backend.vehicle.enums.SituacionRevision;
import com.taxiuap.backend.vehicle.enums.TipoDocumento;

/** Datos de salida de un documento de conductor. */
public record DocumentoConductorResponse(
        Long id,
        Long idConductor,
        Long idVehiculo,
        TipoDocumento tipoDocumento,
        String archivoUrl,
        LocalDate fechaVencimiento,
        SituacionRevision situacionRevision) {
}
