package com.taxiuap.backend.controller.auth;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;

import com.taxiuap.backend.identity.dto.TokenResponse;
import com.taxiuap.backend.identity.service.AutenticacionService;
import com.taxiuap.backend.shared.response.ApiResponse;

import lombok.RequiredArgsConstructor;
import tools.jackson.databind.ObjectMapper;

/**
 * Inicio de sesion con Google OAuth2 (flujo manual de codigo de autorizacion).
 * GET /api/auth/google redirige a la pantalla de consentimiento de Google y
 * GET /api/auth/google/callback recibe el codigo, lo intercambia por un token
 * de acceso, obtiene el perfil y emite los tokens JWT propios.
 */
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class GoogleAuthController {

    private static final Logger log = LoggerFactory.getLogger(GoogleAuthController.class);

    private static final String GOOGLE_AUTH_BASE = "https://accounts.google.com/o/oauth2/v2/auth";
    private static final String GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
    private static final String GOOGLE_USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo";

    private final AutenticacionService autenticacionService;

    /** Serializa mapas a JSON legible para imprimirlos en consola. */
    private final ObjectMapper objectMapper;

    /** Cliente HTTP para llamar a los endpoints de Google (no requiere bean). */
    private final RestTemplate restTemplate = new RestTemplate();

    @Value("${google.client-id:}")
    private String googleClientId;

    @Value("${google.client-secret:}")
    private String googleClientSecret;

    @Value("${google.redirect-uri:http://localhost:8080/api/auth/google/callback}")
    private String googleRedirectUri;

    /**
     * Redirige al usuario a la pantalla de consentimiento de Google.
     * Se piden los scopes openid, email y profile (nombre y foto).
     */
    @GetMapping("/google")
    public ResponseEntity<ApiResponse<Void>> googleLogin() {
        if (googleClientId == null || googleClientId.isBlank()) {
            return ResponseEntity.status(503)
                    .body(ApiResponse.error("Login con Google no configurado: falta GOOGLE_CLIENT_ID en el .env"));
        }

        String state = UUID.randomUUID().toString();
        String scope = "openid email profile";

        StringBuilder authUrl = new StringBuilder(GOOGLE_AUTH_BASE);
        authUrl.append("?response_type=code")
               .append("&client_id=").append(googleClientId)
               .append("&redirect_uri=").append(googleRedirectUri)
               .append("&scope=").append(scope.replace(' ', '+'))
               .append("&state=").append(state);

        return ResponseEntity.status(302)
                .header("Location", authUrl.toString())
                .body(ApiResponse.exito("Redirigiendo a Google", null));
    }

    /**
     * Callback de Google: intercambia el codigo de autorizacion por un token
     * de acceso, consulta el perfil del usuario y emite los tokens JWT.
     */
    @GetMapping("/google/callback")
    public ResponseEntity<ApiResponse<TokenResponse>> googleCallback(
            @RequestParam(name = "code", required = false) String authorizationCode,
            @RequestParam(name = "error", required = false) String error) {

        if (error != null && !error.isBlank()) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("Google rechazo la autorizacion: " + error));
        }
        if (authorizationCode == null || authorizationCode.isBlank()) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("Falta el codigo de autorizacion de Google"));
        }

        try {
            String accessToken = exchangeCodeForAccessToken(authorizationCode);
            Map<String, Object> userInfo = getGoogleUserInfo(accessToken);
            String email = (String) userInfo.get("email");
            String nombre = (String) userInfo.get("name");
            String picture = (String) userInfo.get("picture");

            if (email == null || email.isBlank()) {
                return ResponseEntity.badRequest()
                        .body(ApiResponse.error("No se pudo obtener el email de Google"));
            }

            TokenResponse tokenResponse = autenticacionService.loginConGoogle(email, nombre, picture);

            return ResponseEntity.ok(ApiResponse.exito("Sesion iniciada con Google", tokenResponse));

        } catch (org.springframework.web.client.RestClientException e) {
            return ResponseEntity.status(502)
                    .body(ApiResponse.error("No se pudo comunicar con Google: " + e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(500)
                    .body(ApiResponse.error("Error en login con Google: " + e.getMessage()));
        }
    }

    /**
     * Intercambia el codigo de autorizacion por un token de acceso en el
     * endpoint de tokens de Google.
     */
    @SuppressWarnings("unchecked")
    private String exchangeCodeForAccessToken(String code) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        String body = "code=" + code +
                "&client_id=" + googleClientId +
                "&client_secret=" + googleClientSecret +
                "&redirect_uri=" + googleRedirectUri +
                "&grant_type=authorization_code";

        HttpEntity<String> entity = new HttpEntity<>(body, headers);

        ResponseEntity<Map> response = restTemplate.postForEntity(GOOGLE_TOKEN_URL, entity, Map.class);
        Map<String, Object> cuerpo = response.getBody();
        if (cuerpo == null || cuerpo.get("access_token") == null) {
            throw new IllegalStateException("Google no devolvio access_token");
        }
        log.info("Respuesta de tokens de Google: {}", aJson(enmascararTokens(cuerpo)));
        return (String) cuerpo.get("access_token");
    }

    /**
     * Obtiene el perfil del usuario (email, nombre, foto) desde el endpoint
     * userinfo de Google usando el token de acceso.
     */
    @SuppressWarnings("unchecked")
    private Map<String, Object> getGoogleUserInfo(String accessToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", "Bearer " + accessToken);

        HttpEntity<String> entity = new HttpEntity<>(headers);

        ResponseEntity<Map> response = restTemplate.exchange(
                GOOGLE_USERINFO_URL, HttpMethod.GET, entity, Map.class);
        Map<String, Object> cuerpo = response.getBody();
        if (cuerpo == null) {
            throw new IllegalStateException("Google no devolvio informacion del usuario");
        }
        log.info("Perfil de Google (userinfo): {}", aJson(cuerpo));
        return cuerpo;
    }

    /** Serializa un valor a JSON legible (pretty print) para los logs. */
    private String aJson(Object valor) {
        try {
            return objectMapper.writerWithDefaultPrettyPrinter().writeValueAsString(valor);
        } catch (Exception e) {
            return String.valueOf(valor);
        }
    }

    /**
     * Copia la respuesta de tokens acortando los valores de los tokens: nunca se
     * debe imprimir un token completo en los logs.
     */
    private Map<String, Object> enmascararTokens(Map<String, Object> cuerpo) {
        Map<String, Object> copia = new LinkedHashMap<>(cuerpo);
        for (String clave : List.of("access_token", "id_token", "refresh_token")) {
            Object valor = copia.get(clave);
            if (valor != null) {
                String texto = String.valueOf(valor);
                copia.put(clave, texto.length() > 20 ? texto.substring(0, 20) + "..." : texto);
            }
        }
        return copia;
    }
}
