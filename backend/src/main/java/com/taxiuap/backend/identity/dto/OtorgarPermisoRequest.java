package com.taxiuap.backend.identity.dto;

import java.util.List;

/** Que se le permite actualizar al conductor: sus datos y/o el PDF de documentos puntuales. */
public record OtorgarPermisoRequest(
        boolean datos,
        List<Long> documentos) {
}
