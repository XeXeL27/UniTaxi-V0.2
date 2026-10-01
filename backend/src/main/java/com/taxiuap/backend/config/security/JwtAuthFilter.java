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

import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.identity.service.AutenticacionService;
import com.taxiuap.backend.identity.service.RevisionCarnetService;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

import lombok.RequiredArgsConstructor;

/**
 * Lee el header {@code Authorization: Bearer <token>}, valida el JWT de ACCESO y coloca el
 * usuario en el SecurityContext. No es un @Component: se instancia a mano en SecurityConfig
 * porque solo hay una cadena de seguridad y no hace falta que Spring lo gestione como bean.
 */
@RequiredArgsConstructor
public class JwtAuthFilter extends OncePerRequestFilter {

    /** Atributo del request con el motivo por el que un token valido ya no sirve (lo lee SecurityConfig). */
    public static final String ATRIBUTO_MOTIVO = "taxiuap.motivoNoAutenticado";

    private final JwtService jwtService;
    private final UsuarioRepository usuarioRepository;
    private final PersonaRepository personaRepository;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            try {
                JwtUser usuario = jwtService.validar(header.substring(7), TipoToken.ACCESO);
                // La cuenta suspendida o eliminada queda afuera en su siguiente peticion, aunque su
                // token todavia no haya vencido (el refresco tambien la rechaza).
                EstadoRegistro estado = usuarioRepository.findById(usuario.idUsuario())
                        .map(Usuario::getEstadoUsuario)
                        .orElse(EstadoRegistro.X);
                if (estado != EstadoRegistro.A) {
                    request.setAttribute(ATRIBUTO_MOTIVO, estado == EstadoRegistro.S
                            ? AutenticacionService.MENSAJE_CUENTA_SUSPENDIDA
                            : motivoEliminada(usuario.idUsuario()));
                    SecurityContextHolder.clearContext();
                    chain.doFilter(request, response);
                    return;
                }
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

    /** Si el administrador rechazo sus datos del carnet se le dice por que; si no, el aviso general. */
    private String motivoEliminada(Long idUsuario) {
        return personaRepository.motivoObservacionDeUsuario(idUsuario)
                .flatMap(RevisionCarnetService::mensajeRechazo)
                .orElse("Tu cuenta fue eliminada. Comunicate con la administracion de UNITAXI");
    }
}
