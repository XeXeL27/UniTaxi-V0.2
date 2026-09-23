package com.taxiuap.backend.config.security;

import java.nio.charset.StandardCharsets;
import java.util.Date;

import javax.crypto.SecretKey;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

/**
 * Genera y valida los JWT del API. No depende de ninguna entidad: recibe los datos ya resueltos
 * (id de usuario, sujeto de login y rol) desde el servicio de autenticacion del dominio identity.
 */
@Service
public class JwtService {

    private final SecretKey clave;
    private final long expiracionMs;
    private final long expiracionRefrescoMs;

    public JwtService(@Value("${jwt.secret}") String secreto,
                       @Value("${jwt.expiration:86400000}") long expiracionMs,
                       @Value("${jwt.refresh-expiration:604800000}") long expiracionRefrescoMs) {
        this.clave = Keys.hmacShaKeyFor(secreto.getBytes(StandardCharsets.UTF_8));
        this.expiracionMs = expiracionMs;
        this.expiracionRefrescoMs = expiracionRefrescoMs;
    }

    public String generarAcceso(Long idUsuario, String sujeto, String rol) {
        return generar(idUsuario, sujeto, rol, TipoToken.ACCESO, expiracionMs);
    }

    public String generarRefresco(Long idUsuario, String sujeto, String rol) {
        return generar(idUsuario, sujeto, rol, TipoToken.REFRESCO, expiracionRefrescoMs);
    }

    private String generar(Long idUsuario, String sujeto, String rol, TipoToken tipo, long duracionMs) {
        Date ahora = new Date();
        return Jwts.builder()
                .subject(sujeto)
                .claim("uid", idUsuario)
                .claim("rol", rol)
                .claim("tipo", tipo.name())
                .issuedAt(ahora)
                .expiration(new Date(ahora.getTime() + duracionMs))
                .signWith(clave)
                .compact();
    }

    /** Valida firma, expiracion y que el token sea del tipo esperado (ACCESO o REFRESCO). */
    public JwtUser validar(String token, TipoToken tipoEsperado) {
        Claims claims = Jwts.parser().verifyWith(clave).build().parseSignedClaims(token).getPayload();
        String tipo = claims.get("tipo", String.class);
        if (tipo == null || !tipo.equals(tipoEsperado.name())) {
            throw new JwtException("Tipo de token invalido");
        }
        Long idUsuario = (claims.get("uid") instanceof Number n) ? n.longValue() : null;
        return new JwtUser(idUsuario, claims.getSubject(), claims.get("rol", String.class));
    }

    public long getExpiracionMs() {
        return expiracionMs;
    }
}
