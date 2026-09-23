package com.taxiuap.backend.config.security;

import java.util.Optional;

import org.springframework.data.domain.AuditorAware;
import org.springframework.stereotype.Component;

/** Provee el id de usuario autenticado a la auditoria JPA (creado_por / modificado_por). */
@Component("auditorAware")
public class AuditorAwareImpl implements AuditorAware<Long> {

    @Override
    public Optional<Long> getCurrentAuditor() {
        return UsuarioActual.obtener().map(JwtUser::idUsuario);
    }
}
