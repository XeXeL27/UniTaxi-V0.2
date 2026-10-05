package com.taxiuap.backend.institution.dto;

import java.time.LocalDate;

/**
 * Situacion de estudiante UAP de una persona: NINGUNO (no es estudiante), VERIFICADO (matricula
 * vigente: tiene descuento), VENCIDO (hay que volver a consultar el SIGSE), PENDIENTE (su registro
 * esta observado y lo revisa un administrador) o RECHAZADO. descuento: Bs por viaje mientras este
 * VERIFICADO. fotoDelSigse: al verificarse se le puso la foto del SIGSE porque no tenia foto de perfil.
 */
public record EstadoEstudianteResponse(
        String situacion,
        String ru,
        String carrera,
        String periodo,
        LocalDate venceEl,
        Integer descuento,
        boolean fotoDelSigse) {

    public static EstadoEstudianteResponse ninguno() {
        return new EstadoEstudianteResponse("NINGUNO", null, null, null, null, null, false);
    }

    public EstadoEstudianteResponse conFotoDelSigse(boolean foto) {
        return new EstadoEstudianteResponse(situacion, ru, carrera, periodo, venceEl, descuento, foto);
    }
}
