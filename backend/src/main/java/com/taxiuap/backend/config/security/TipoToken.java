package com.taxiuap.backend.config.security;

/** Tipo de JWT emitido por JwtService. El filtro de autenticacion solo acepta tokens de ACCESO. */
public enum TipoToken {
    ACCESO,
    REFRESCO
}
