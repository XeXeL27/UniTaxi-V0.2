package com.taxiuap.backend.shared.exception;

/**
 * Credenciales correctas de una cuenta suspendida. Responde 422 como NegocioException y ademas
 * errores.cuenta = SUSPENDIDA, para que la app ofrezca escribirle al administrador.
 */
public class CuentaSuspendidaException extends NegocioException {

    public CuentaSuspendidaException(String mensaje) {
        super(mensaje);
    }
}
