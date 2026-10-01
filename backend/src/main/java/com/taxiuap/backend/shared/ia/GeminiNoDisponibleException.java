package com.taxiuap.backend.shared.ia;

/**
 * Gemini no pudo leer: falta la llave, no hay conexion, se acabo la cuota o Google rechazo la llave.
 * Quien llama decide que hacer (la app vuelve a leer con ML Kit en el telefono).
 */
public class GeminiNoDisponibleException extends RuntimeException {

    public GeminiNoDisponibleException(String mensaje) {
        super(mensaje);
    }
}
