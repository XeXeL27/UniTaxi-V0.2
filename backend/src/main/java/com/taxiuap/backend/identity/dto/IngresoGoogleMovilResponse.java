package com.taxiuap.backend.identity.dto;

/**
 * Resultado del ingreso con Google: la sesion ya iniciada, o un codigo temporal para terminar un
 * registro sin haber guardado nada todavia: [codigoRegistro] para el formulario de conductor y
 * [codigoRegistroPasajero] para el carnet del pasajero nuevo. [aviso]: mensaje para mostrar antes de
 * entrar (por ejemplo, pidio conductor pero su registro sigue en revision).
 */
public record IngresoGoogleMovilResponse(TokenResponse sesion, String codigoRegistro, String aviso,
        String codigoRegistroPasajero) {

    public static IngresoGoogleMovilResponse sesion(TokenResponse sesion) {
        return new IngresoGoogleMovilResponse(sesion, null, null, null);
    }

    public static IngresoGoogleMovilResponse registroPasajero(String codigo) {
        return new IngresoGoogleMovilResponse(null, null, null, codigo);
    }
}
