package com.taxiuap.backend.shared.exception;

/**
 * Se lanza cuando un UPDATE condicional (por ejemplo, aceptar una oferta de viaje) afecta 0
 * filas, es decir, el recurso ya cambio de estado por otra peticion concurrente. El manejador
 * global responde 409.
 */
public class ConflictoException extends RuntimeException {

    public ConflictoException(String mensaje) {
        super(mensaje);
    }
}
