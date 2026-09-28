package com.taxiuap.backend.identity.dto;

import java.time.LocalDateTime;

import com.taxiuap.backend.identity.enums.TipoPermisoEdicion;

/** Permiso de edicion de un conductor, con su vencimiento. */
public record PermisoEdicionResponse(
        Long id,
        TipoPermisoEdicion tipo,
        Long idDocumento,
        String tipoDocumento,
        LocalDateTime otorgadoEn,
        LocalDateTime venceEn,
        LocalDateTime usadoEn,
        boolean vigente) {
}
