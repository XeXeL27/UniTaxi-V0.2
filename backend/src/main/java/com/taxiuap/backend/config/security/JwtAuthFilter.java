package com.taxiuap.backend.config.security;

import java.io.IOException;
import java.util.List;

import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;

/**
 * Lee el header {@code Authorization: Bearer <token>}, valida el JWT de ACCESO y coloca el
 * usuario en el SecurityContext. No es un @Component: se instancia a mano en SecurityConfig
 * porque solo hay una cadena de seguridad y no hace falta que Spring lo gestione como bean.
 */
@RequiredArgsConstructor
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtService jwtService;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            try {
                JwtUser usuario = jwtService.validar(header.substring(7), TipoToken.ACCESO);
                var auth = new UsernamePasswordAuthenticationToken(
                        usuario, null, List.of(new SimpleGrantedAuthority("ROLE_" + usuario.rol())));
                SecurityContextHolder.getContext().setAuthentication(auth);
            } catch (Exception e) {
                // Token invalido, expirado o de tipo distinto a ACCESO: se continua sin
                // autenticacion; el endpoint protegido respondera 401/403 mas adelante.
                SecurityContextHolder.clearContext();
            }
        }
        chain.doFilter(request, response);
    }
}
