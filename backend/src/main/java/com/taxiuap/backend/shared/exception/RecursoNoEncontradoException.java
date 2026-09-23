package com.taxiuap.backend.shared.exception;

/** Se lanza cuando el recurso solicitado no existe. El manejador global responde 404. */
public class RecursoNoEncontradoException extends RuntimeException {

    public RecursoNoEncontradoException(String mensaje) {
        super(mensaje);
    }

    public static RecursoNoEncontradoException de(String recurso, Object id) {
        return new RecursoNoEncontradoException(recurso + " no encontrado con id " + id);
    }
}
