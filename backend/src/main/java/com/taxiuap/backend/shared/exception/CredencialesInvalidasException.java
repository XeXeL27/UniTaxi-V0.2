package com.taxiuap.backend.shared.exception;

/** Se lanza cuando el login falla por credenciales incorrectas o token de refresco invalido. */
public class CredencialesInvalidasException extends RuntimeException {

    public CredencialesInvalidasException(String mensaje) {
        super(mensaje);
    }
}
