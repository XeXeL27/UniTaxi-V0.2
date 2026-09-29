package com.taxiuap.backend.identity.dto;

/**
 * Resultado del ingreso con Google desde el APK: la sesion ya iniciada, o el codigo (2 minutos, un
 * solo uso) para terminar el registro de conductor con el formulario. [aviso]: mensaje para mostrar
 * antes de entrar (por ejemplo, pidio conductor pero su registro sigue en revision).
 */
public record IngresoGoogleMovilResponse(TokenResponse sesion, String codigoRegistro, String aviso) {

    public static IngresoGoogleMovilResponse sesion(TokenResponse sesion) {
        return new IngresoGoogleMovilResponse(sesion, null, null);
    }
}
