package com.taxiuap.backend.shared.exception;

/** Se lanza cuando una operacion viola una regla de negocio. El manejador global responde 422. */
public class NegocioException extends RuntimeException {

    public NegocioException(String mensaje) {
        super(mensaje);
    }
}
