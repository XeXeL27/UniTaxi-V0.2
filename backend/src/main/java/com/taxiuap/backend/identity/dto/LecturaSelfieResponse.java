package com.taxiuap.backend.identity.dto;

/**
 * Lo que Gemini reviso de la foto de la persona sosteniendo su carnet.
 *
 * disponible = false: el servidor no pudo revisarla (sin llave, sin cuota, sin conexion); se acepta y la
 * cuenta queda OBSERVADA para el administrador. aceptada = false: la foto no sirve y motivo dice que
 * corregir. numero: el del carnet que sostiene. observacion: la foto se acepta pero la cuenta queda
 * OBSERVADA por ese motivo (la cara no se parece a la del carnet o parece foto de una pantalla).
 */
public record LecturaSelfieResponse(
        boolean disponible,
        boolean aceptada,
        String motivo,
        String numero,
        String observacion) {

    public static LecturaSelfieResponse noDisponible() {
        return new LecturaSelfieResponse(false, false, null, null, null);
    }

    public static LecturaSelfieResponse rechazada(String motivo) {
        return new LecturaSelfieResponse(true, false, motivo, null, null);
    }
}
