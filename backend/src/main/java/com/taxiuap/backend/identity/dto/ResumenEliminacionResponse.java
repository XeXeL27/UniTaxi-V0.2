package com.taxiuap.backend.identity.dto;

import java.util.List;

/**
 * Lo que se borra de forma permanente al eliminar una persona, para mostrarlo antes de confirmar.
 * viajesConservados: viajes con otra persona que se conservan a nombre de "USUARIO ELIMINADO".
 * bloqueo: por que no se puede eliminar ahora (null si se puede). confirmacion: lo que el
 * administrador debe escribir para confirmar (el correo o, sin correo, el CI).
 */
public record ResumenEliminacionResponse(
        Long idPersona,
        String nombreCompleto,
        String correo,
        String ci,
        List<Elemento> seElimina,
        long viajesConservados,
        long calificacionesConservadas,
        String bloqueo,
        String confirmacion) {

    public record Elemento(String concepto, long cantidad) {
    }
}
