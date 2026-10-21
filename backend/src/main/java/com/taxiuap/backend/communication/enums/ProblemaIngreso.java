package com.taxiuap.backend.communication.enums;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/**
 * Problemas que la persona marca al escribir al administrador desde el login (puede marcar varios).
 * Con OTRO escribe el motivo.
 */
@Getter
@RequiredArgsConstructor
public enum ProblemaIngreso {
    CUENTA_SUSPENDIDA("Mi cuenta está suspendida"),
    OLVIDE_CONTRASENA("Olvidé mi contraseña"),
    NO_RECUERDO_USUARIO("No recuerdo mi usuario"),
    NO_LLEGA_CODIGO("No me llega el código o el correo"),
    SIN_ACCESO_CORREO("Ya no uso el correo que registré"),
    DATOS_INCORRECTOS("Mis datos están mal"),
    OTRO("Otro");

    private final String etiqueta;
}
