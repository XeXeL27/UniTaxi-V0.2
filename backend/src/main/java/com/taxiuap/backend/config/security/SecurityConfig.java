package com.taxiuap.backend.config.security;

import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import jakarta.servlet.http.HttpServletResponse;

/**
 * Seguridad de TaxiUAP: una unica cadena JWT, stateless, para todo el API.
 *
 * A diferencia de uniFex (que mantiene dos cadenas: una JWT para el API y otra con sesion y
 * Thymeleaf para el sitio web), aqui no existe sitio web ni sesion: pasajero, conductor y admin
 * usan siempre token JWT, asi que una sola cadena cubre todo. Tampoco hay UserDetailsService:
 * el login (dominio identity) valida la contrasena con PasswordEncoder y emite el JWT.
 */
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private static final String ORIGENES_POR_DEFECTO = "http://localhost:5173,http://127.0.0.1:5173";

    @Value("${cors.origenes:}")
    private String origenesCors;

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        String origenes = (origenesCors == null || origenesCors.isBlank()) ? ORIGENES_POR_DEFECTO : origenesCors;

        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(List.of(origenes.split("\\s*,\\s*")));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http, JwtService jwtService,
            UsuarioRepository usuarioRepository, PersonaRepository personaRepository) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .cors(cors -> {})
                .httpBasic(basic -> basic.disable())
                .formLogin(form -> form.disable())
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers("/api/auth/**", "/api/publico/**", "/ws/**", "/error").permitAll()
                        // Paginas del panel y de la app (ver SitiosWebConfig); los datos siguen protegidos en /api.
                        .requestMatchers("/", "/ingresar", "/admin", "/admin/**", "/app", "/app/**").permitAll()
                        .requestMatchers("/api/pasajero/**").hasRole(RolSistema.PASAJERO.getCodigo())
                        .requestMatchers("/api/conductor/**").hasRole(RolSistema.CONDUCTOR.getCodigo())
                        .requestMatchers("/api/admin/**").hasRole(RolSistema.ADMIN.getCodigo())
                        .anyRequest().authenticated())
                // setStatus + write (no sendError) para responder JSON directo: sendError hace
                // un forward interno a /error, que aqui no tiene una vista propia que devolver.
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint((req, res, e) -> escribir(res, HttpServletResponse.SC_UNAUTHORIZED,
                                req.getAttribute(JwtAuthFilter.ATRIBUTO_MOTIVO) instanceof String motivo ? motivo :
                                "No autenticado"))
                        .accessDeniedHandler((req, res, e) -> escribir(res, HttpServletResponse.SC_FORBIDDEN,
                                "Sin permiso para este recurso")))
                .addFilterBefore(new JwtAuthFilter(jwtService, usuarioRepository, personaRepository), UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    private void escribir(HttpServletResponse res, int estado, String mensaje) throws java.io.IOException {
        res.setStatus(estado);
        res.setContentType("application/json;charset=UTF-8");
        String json = "{\"ok\":false,\"mensaje\":\"" + mensaje.replace("\"", "\\\"") + "\"}";
        res.getWriter().write(json);
    }
}
