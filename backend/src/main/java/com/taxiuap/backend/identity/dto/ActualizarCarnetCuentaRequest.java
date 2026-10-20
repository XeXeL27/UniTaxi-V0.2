package com.taxiuap.backend.identity.dto;

/**
 * Parte "datos" de POST /api/cuenta/carnet/actualizar (cuenta que ya usaba la app).
 *
 * confirmaDatos: la persona vio y confirmo los datos leidos de su carnet; si su cuenta tiene otro dato (nombre
 * incompleto, fecha, complemento) o uno vacio, se actualiza con el del carnet.
 * observado: "Mis fotos estan bien, enviar a revision": no se cambia nada y lo revisa un administrador.
 * Sin esta parte (apps anteriores) no se actualiza ningun dato: si no coinciden, se rechaza.
 */
public record ActualizarCarnetCuentaRequest(Boolean confirmaDatos, Boolean observado) {

    public boolean confirma() {
        return Boolean.TRUE.equals(confirmaDatos);
    }

    public boolean esObservado() {
        return Boolean.TRUE.equals(observado);
    }
}
