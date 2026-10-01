package com.taxiuap.backend.identity.dto;

import java.util.List;

/**
 * Que se le permite actualizar al conductor: sus datos, el PDF de documentos puntuales y/o volver a
 * tomar las fotos del carnet o de la licencia.
 */
public record OtorgarPermisoRequest(
        boolean datos,
        List<Long> documentos,
        boolean carnet,
        boolean licencia) {
}
