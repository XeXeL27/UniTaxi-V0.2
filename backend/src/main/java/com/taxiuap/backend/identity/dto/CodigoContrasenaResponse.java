package com.taxiuap.backend.identity.dto;

/**
 * Perfil > Cambiar contrasena: a que correo llega el codigo (oculto en parte, por ejemplo cr***@gmail.com).
 *
 * puedeRecibirCodigo = false si la cuenta no tiene correo registrado (solo queda la contrasena actual).
 * segundosParaReenviar: cuanto falta para poder pedir otro codigo (0 = ya se puede).
 * minutosVigencia: cuanto vale el codigo enviado.
 */
public record CodigoContrasenaResponse(
        String correo,
        boolean puedeRecibirCodigo,
        long segundosParaReenviar,
        long minutosVigencia) {
}
