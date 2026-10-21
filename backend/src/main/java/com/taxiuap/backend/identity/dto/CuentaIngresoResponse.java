package com.taxiuap.backend.identity.dto;

/**
 * Una cuenta con la que la persona puede ingresar. rol: PASAJERO, CONDUCTOR o ADMIN (lo que se envia
 * en el login). tipo: igual al rol, salvo DELIVERY para el conductor con moto de reparto.
 */
public record CuentaIngresoResponse(String rol, String tipo) {
}
