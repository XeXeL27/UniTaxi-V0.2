package com.taxiuap.backend.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/**
 * uniFex tenia las anotaciones de auditoria (@CreatedDate, @CreatedBy, etc.) pero nunca activo
 * @EnableJpaAuditing, asi que esos campos nunca se llenaban solos. Aqui si esta activa: el
 * auditor (quien crea/modifica) se resuelve con el bean "auditorAware"
 * (config/security/AuditorAwareImpl), que toma el id de usuario del JWT autenticado.
 */
@Configuration
@EnableJpaAuditing(auditorAwareRef = "auditorAware")
public class AuditoriaConfig {
}
