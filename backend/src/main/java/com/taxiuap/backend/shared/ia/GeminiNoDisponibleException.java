package com.taxiuap.backend.shared.ia;

/** Gemini no pudo leer: falta la llave, no hay conexion, se acabo la cuota o Google rechazo la llave. */
public class GeminiNoDisponibleException extends IaNoDisponibleException {

    public GeminiNoDisponibleException(String mensaje) {
        super(mensaje);
    }
}
