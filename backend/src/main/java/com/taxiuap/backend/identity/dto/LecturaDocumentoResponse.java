package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;

/**
 * Lo que Gemini leyo de UNA foto del carnet o de la licencia.
 *
 * disponible = false: el servidor no pudo leer (sin llave, sin cuota, sin conexion) y la app lee con
 * su lector del telefono. aceptada = false: la foto no es el documento y lado pedidos o no se lee
 * bien; motivo dice que corregir. formato: NUEVO o ANTIGUO (carnet) o LICENCIA.
 *
 * nombreSeparado: el documento separa nombres de apellidos (etiquetas, MRZ o la coma de la licencia);
 * si no (carnet antiguo) nombres y apellidos son el corte que propone Gemini con las mismas palabras de
 * nombreCompleto (null si no pudo). nombreCortado: la MRZ corto los nombres.
 */
public record LecturaDocumentoResponse(
        boolean disponible,
        boolean aceptada,
        String motivo,
        String formato,
        String numero,
        String complemento,
        String nombres,
        String apellidos,
        String nombreCompleto,
        boolean nombreSeparado,
        boolean nombreCortado,
        LocalDate fechaNacimiento,
        String categoria,
        LocalDate vencimiento) {

    public static LecturaDocumentoResponse noDisponible() {
        return new LecturaDocumentoResponse(false, false, null, null, null, null, null, null, null, false, false,
                null, null, null);
    }

    public static LecturaDocumentoResponse rechazada(String motivo) {
        return new LecturaDocumentoResponse(true, false, motivo, null, null, null, null, null, null, false, false,
                null, null, null);
    }
}
