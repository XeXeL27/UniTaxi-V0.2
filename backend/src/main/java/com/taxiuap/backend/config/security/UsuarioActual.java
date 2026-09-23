package com.taxiuap.backend.config.security;

import java.util.Optional;

import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.security.core.context.SecurityContextHolder;

/** Acceso al usuario autenticado de la peticion actual, tomado del SecurityContext. */
public final class UsuarioActual {

    private UsuarioActual() {
    }

    public static Optional<JwtUser> obtener() {
        var authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.getPrincipal() instanceof JwtUser jwtUser) {
            return Optional.of(jwtUser);
        }
        return Optional.empty();
    }

    public static Long idUsuario() {
        return obtener().map(JwtUser::idUsuario)
                .orElseThrow(() -> new AuthenticationCredentialsNotFoundException("No hay usuario autenticado"));
    }
}
