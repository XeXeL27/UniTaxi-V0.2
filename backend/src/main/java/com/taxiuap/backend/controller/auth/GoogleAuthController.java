package com.taxiuap.backend.controller.auth;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.dto.CanjeGoogleRequest;
import com.taxiuap.backend.identity.dto.IngresoGoogleMovilRequest;
import com.taxiuap.backend.identity.dto.IngresoGoogleMovilResponse;
import com.taxiuap.backend.identity.dto.PerfilGoogle;
import com.taxiuap.backend.identity.dto.PerfilGoogleResponse;
import com.taxiuap.backend.identity.dto.RegistroConductorGoogleRequest;
import com.taxiuap.backend.identity.dto.TokenResponse;
import com.taxiuap.backend.identity.enums.ModoIngresoGoogle;
import com.taxiuap.backend.identity.service.IngresoGoogleTemporal;
import com.taxiuap.backend.identity.service.IngresoGoogleTemporal.Pedido;
import com.taxiuap.backend.identity.service.RegistroGoogleService;
import com.taxiuap.backend.shared.exception.ConflictoException;
import com.taxiuap.backend.shared.exception.CredencialesInvalidasException;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Ingreso y registro con Google (flujo de codigo de autorizacion de OAuth2).
 *
 * 1. La app abre GET /api/auth/google?modo=...&volver=... y el navegador va a Google.
 * 2. Google vuelve a /api/auth/google/callback; se canjea el codigo por el perfil de la persona.
 * 3. Se redirige a la app (volver) con ?google=codigo (sesion lista, se recoge con POST
 *    /api/auth/google/canje), ?google_registro=codigo (conductor nuevo: falta el formulario) o
 *    ?google_error=mensaje. Los JWT nunca viajan en la URL.
 */
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class GoogleAuthController {

    private static final Logger LOG = LoggerFactory.getLogger(GoogleAuthController.class);

    private final RegistroGoogleService registroGoogleService;
    private final IngresoGoogleTemporal temporal;

    /** Cliente HTTP para llamar a los endpoints de Google (no requiere bean). */
    private final RestTemplate restTemplate = new RestTemplate();

    @Value("${google.client-id:}")
    private String googleClientId;

    @Value("${google.client-secret:}")
    private String googleClientSecret;

    @Value("${google.redirect-uri:http://localhost:8080/api/auth/google/callback}")
    private String googleRedirectUri;

    /** URLs de Google; se pueden cambiar solo para probar el flujo contra un servidor falso. */
    @Value("${google.auth-url:https://accounts.google.com/o/oauth2/v2/auth}")
    private String googleAuthUrl;

    @Value("${google.token-url:https://oauth2.googleapis.com/token}")
    private String googleTokenUrl;

    @Value("${google.userinfo-url:https://www.googleapis.com/oauth2/v2/userinfo}")
    private String googleUserinfoUrl;

    /** Verificacion del id_token que entrega Google Sign-In en el APK. */
    @Value("${google.tokeninfo-url:https://oauth2.googleapis.com/tokeninfo}")
    private String googleTokeninfoUrl;

    /** Origenes del panel y la app con flutter run: tambien pueden recibir la vuelta de Google. */
    @Value("${cors.origenes:}")
    private String origenesCors;

    /** Envia a la pantalla de Google para elegir la cuenta. */
    @GetMapping("/google")
    public ResponseEntity<?> iniciar(
            @RequestParam(name = "modo", defaultValue = "INGRESO") ModoIngresoGoogle modo,
            @RequestParam(name = "volver", required = false) String volver) {
        if (googleClientId == null || googleClientId.isBlank()) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                    .body(ApiResponse.error("Login con Google no configurado: falta GOOGLE_CLIENT_ID en el .env"));
        }
        String destino = volverPermitido(volver);
        String estado = temporal.guardarEstado(new Pedido(modo, destino));
        String url = googleAuthUrl
                + "?response_type=code"
                + "&client_id=" + codificar(googleClientId)
                + "&redirect_uri=" + codificar(googleRedirectUri)
                + "&scope=" + codificar("openid email profile")
                + "&prompt=select_account"
                + "&state=" + codificar(estado);
        return redirigir(url);
    }

    /** Vuelta de Google: siempre termina redirigiendo a la app, con la sesion o con el error. */
    @GetMapping("/google/callback")
    public ResponseEntity<?> vuelta(
            @RequestParam(name = "code", required = false) String codigoGoogle,
            @RequestParam(name = "state", required = false) String estado,
            @RequestParam(name = "error", required = false) String error) {
        Pedido pedido = temporal.tomarEstado(estado).orElse(null);
        if (pedido == null) {
            return volverCon(volverPorDefecto(), "google_error",
                    "El ingreso con Google vencio o no se inicio desde la app. Vuelve a intentarlo.");
        }
        if (error != null && !error.isBlank()) {
            return volverCon(pedido.volver(), "google_error",
                    "access_denied".equals(error) ? "Cancelaste el ingreso con Google." : "Google rechazo el ingreso: " + error);
        }
        if (codigoGoogle == null || codigoGoogle.isBlank()) {
            return volverCon(pedido.volver(), "google_error", "Google no devolvio el codigo de autorizacion.");
        }

        try {
            IngresoGoogleMovilResponse resultado = resolver(perfilDe(codigoGoogle), pedido.modo());
            return resultado.sesion() != null
                    ? volverCon(pedido.volver(), "google", temporal.guardarCanje(resultado.sesion()))
                    : volverCon(pedido.volver(), "google_registro", resultado.codigoRegistro());
        } catch (NegocioException | ConflictoException e) {
            return volverCon(pedido.volver(), "google_error", e.getMessage());
        } catch (RestClientException | IllegalStateException e) {
            LOG.warn("Fallo el ingreso con Google", e);
            return volverCon(pedido.volver(), "google_error", "No se pudo comunicar con Google. Intentalo de nuevo.");
        } catch (RuntimeException e) {
            // Siempre se vuelve a la app: un JSON de error en el navegador dejaria al usuario varado.
            LOG.error("Error inesperado en el ingreso con Google", e);
            return volverCon(pedido.volver(), "google_error", "No se pudo completar el ingreso con Google.");
        }
    }

    /** Client ID web de Google: el APK lo usa como serverClientId para pedir el id_token. */
    @GetMapping("/google/config")
    public ResponseEntity<ApiResponse<Map<String, String>>> configuracion() {
        if (googleClientId == null || googleClientId.isBlank()) {
            throw new NegocioException("Login con Google no configurado: falta GOOGLE_CLIENT_ID en el .env");
        }
        return ResponseEntity.ok(ApiResponse.exito(Map.of("clientId", googleClientId)));
    }

    /**
     * Ingreso con Google desde el APK (Google Sign-In nativo, sin redireccion: Google no acepta volver
     * a http://IP-de-la-red). Se verifica el id_token con Google y se sigue la misma logica que la web:
     * sesion iniciada, o codigo para el formulario de conductor.
     */
    @PostMapping("/google/movil")
    public ResponseEntity<ApiResponse<IngresoGoogleMovilResponse>> ingresarMovil(
            @Valid @RequestBody IngresoGoogleMovilRequest datos) {
        PerfilGoogle perfil;
        try {
            perfil = perfilDeIdToken(datos.idToken());
        } catch (RestClientException e) {
            throw new CredencialesInvalidasException("Google no reconocio el ingreso: vuelve a intentarlo");
        }
        IngresoGoogleMovilResponse resultado = resolver(perfil, datos.modo());
        return ResponseEntity.ok(ApiResponse.exito(
                resultado.sesion() != null ? "Sesion iniciada con Google" : "Completa tus datos de conductor", resultado));
    }

    /** La app recoge la sesion con el codigo de la URL de vuelta (una sola vez, 2 minutos). */
    @PostMapping("/google/canje")
    public ResponseEntity<ApiResponse<TokenResponse>> canjear(@Valid @RequestBody CanjeGoogleRequest datos) {
        TokenResponse tokens = temporal.tomarCanje(datos.codigo())
                .orElseThrow(() -> new CredencialesInvalidasException("El ingreso con Google vencio: vuelve a intentarlo"));
        return ResponseEntity.ok(ApiResponse.exito("Sesion iniciada con Google", tokens));
    }

    /** Nombre y correo de Google para mostrarlos en el formulario de conductor. */
    @GetMapping("/google/registro/{codigo}")
    public ResponseEntity<ApiResponse<PerfilGoogleResponse>> perfilRegistro(@PathVariable String codigo) {
        PerfilGoogle perfil = perfilRegistroVigente(codigo);
        return ResponseEntity.ok(ApiResponse.exito(registroGoogleService.perfilParaRegistro(perfil)));
    }

    /**
     * Termina el registro de conductor con Google. Multipart: "datos" (JSON) y un PDF por parte con
     * el tipo de documento como nombre (CI y LICENCIA obligatorios).
     */
    @PostMapping(value = "/registro/conductor/google", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<TokenResponse>> registrarConductor(
            @Valid @RequestPart("datos") RegistroConductorGoogleRequest datos,
            @RequestParam Map<String, MultipartFile> archivos) {
        PerfilGoogle perfil = perfilRegistroVigente(datos.codigo());
        TokenResponse tokens = registroGoogleService.registrarConductor(perfil, datos, archivos);
        temporal.terminarRegistro(datos.codigo());
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Registro enviado a revision", tokens));
    }

    // ------------------------------------------------------------------ Google

    /**
     * Lo mismo para la web y el APK: INGRESO entra con la cuenta que tenga (o la registra como
     * pasajero), PASAJERO registra, CONDUCTOR entra si ya es conductor o da el codigo del formulario.
     */
    private IngresoGoogleMovilResponse resolver(PerfilGoogle perfil, ModoIngresoGoogle modo) {
        return switch (modo) {
            case INGRESO -> IngresoGoogleMovilResponse.sesion(registroGoogleService.ingresar(perfil, foto(perfil)));
            case PASAJERO -> IngresoGoogleMovilResponse.sesion(registroGoogleService.registrarPasajero(perfil, foto(perfil)));
            // Conductor sin aprobar que tambien es pasajero: entra como pasajero con un aviso.
            case CONDUCTOR -> registroGoogleService.conductorExistente(perfil)
                    .map(tokens -> new IngresoGoogleMovilResponse(tokens, null,
                            "CONDUCTOR".equals(tokens.usuario().rol()) ? null
                                    : "Tu registro de conductor todavia esta en revision. Por ahora entras como pasajero."))
                    .orElseGet(() -> new IngresoGoogleMovilResponse(null, temporal.guardarRegistro(perfil), null));
        };
    }

    /** Verifica con Google el id_token del APK: firma, vigencia, que sea para esta app y correo verificado. */
    private PerfilGoogle perfilDeIdToken(String idToken) {
        // URI ya codificada: con un String RestTemplate la volveria a codificar.
        Map<String, Object> datos = restTemplate.exchange(
                URI.create(googleTokeninfoUrl + "?id_token=" + codificar(idToken)), HttpMethod.GET, null,
                new ParameterizedTypeReference<Map<String, Object>>() { }).getBody();
        if (datos == null || !googleClientId.equals(datos.get("aud"))) {
            throw new CredencialesInvalidasException("El ingreso con Google no es para esta aplicacion");
        }
        if (!(datos.get("email") instanceof String correo) || correo.isBlank()) {
            throw new NegocioException("Google no compartio el correo de la cuenta");
        }
        if (!"true".equals(String.valueOf(datos.get("email_verified")))) {
            throw new NegocioException("El correo de esa cuenta de Google no esta verificado");
        }
        return PerfilGoogle.desde(correo, texto(datos.get("name")), texto(datos.get("given_name")),
                texto(datos.get("family_name")), texto(datos.get("picture")));
    }

    private PerfilGoogle perfilDe(String codigoGoogle) {
        HttpHeaders cabeceras = new HttpHeaders();
        cabeceras.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
        MultiValueMap<String, String> cuerpo = new LinkedMultiValueMap<>();
        cuerpo.add("code", codigoGoogle);
        cuerpo.add("client_id", googleClientId);
        cuerpo.add("client_secret", googleClientSecret);
        cuerpo.add("redirect_uri", googleRedirectUri);
        cuerpo.add("grant_type", "authorization_code");
        Map<String, Object> token = restTemplate.exchange(googleTokenUrl, HttpMethod.POST,
                new HttpEntity<>(cuerpo, cabeceras), new ParameterizedTypeReference<Map<String, Object>>() { }).getBody();
        if (token == null || token.get("access_token") == null) {
            throw new IllegalStateException("Google no devolvio access_token");
        }

        HttpHeaders autorizacion = new HttpHeaders();
        autorizacion.setBearerAuth((String) token.get("access_token"));
        Map<String, Object> datos = restTemplate.exchange(googleUserinfoUrl, HttpMethod.GET,
                new HttpEntity<>(autorizacion), new ParameterizedTypeReference<Map<String, Object>>() { }).getBody();
        if (datos == null || !(datos.get("email") instanceof String correo) || correo.isBlank()) {
            throw new NegocioException("Google no compartio el correo de la cuenta");
        }
        if (Boolean.FALSE.equals(datos.get("verified_email"))) {
            throw new NegocioException("El correo de esa cuenta de Google no esta verificado");
        }
        return PerfilGoogle.desde(correo, texto(datos.get("name")), texto(datos.get("given_name")),
                texto(datos.get("family_name")), texto(datos.get("picture")));
    }

    /** Foto de la cuenta de Google en 512 px; null si no hay o no se pudo bajar (es opcional). */
    private byte[] foto(PerfilGoogle perfil) {
        if (perfil.foto() == null) return null;
        try {
            return restTemplate.getForObject(perfil.foto().replaceAll("=s\\d+(-c)?$", "=s512-c"), byte[].class);
        } catch (RestClientException e) {
            return null;
        }
    }

    private PerfilGoogle perfilRegistroVigente(String codigo) {
        return temporal.verRegistro(codigo)
                .orElseThrow(() -> new NegocioException(
                        "El registro con Google vencio: vuelve a elegir tu cuenta de Google"));
    }

    // ------------------------------------------------------------------ vuelta a la app

    /**
     * Solo se vuelve a origenes conocidos (el del backend y los de cors.origenes); cualquier otro
     * seria una redireccion abierta que entregaria el codigo de la sesion a un sitio ajeno.
     */
    private String volverPermitido(String volver) {
        if (volver == null || volver.isBlank()) return volverPorDefecto();
        try {
            URI uri = URI.create(volver);
            String origen = origenDe(uri);
            if (origen != null && origenesPermitidos().contains(origen)) {
                // Sin query ni fragmento: la app lee solo los parametros de esta vuelta.
                return origen + (uri.getPath() == null || uri.getPath().isEmpty() ? "/" : uri.getPath());
            }
        } catch (IllegalArgumentException e) {
            // URL mal formada: se usa la de siempre.
        }
        return volverPorDefecto();
    }

    private Set<String> origenesPermitidos() {
        Stream<String> cors = origenesCors == null ? Stream.empty() : Arrays.stream(origenesCors.split("\\s*,\\s*"));
        return Stream.concat(Stream.of(origenDe(URI.create(googleRedirectUri))), cors)
                .filter(o -> o != null && !o.isBlank())
                .map(o -> o.replaceAll("/+$", ""))
                .collect(Collectors.toSet());
    }

    private String volverPorDefecto() {
        return origenDe(URI.create(googleRedirectUri)) + "/app/";
    }

    private static String origenDe(URI uri) {
        if (uri.getScheme() == null || uri.getHost() == null) return null;
        return uri.getScheme() + "://" + uri.getHost() + (uri.getPort() == -1 ? "" : ":" + uri.getPort());
    }

    private ResponseEntity<Void> volverCon(String volver, String parametro, String valor) {
        return redirigir(volver + (volver.contains("?") ? "&" : "?") + parametro + "=" + codificar(valor));
    }

    private static <T> ResponseEntity<T> redirigir(String url) {
        return ResponseEntity.status(HttpStatus.FOUND).header(HttpHeaders.LOCATION, url).build();
    }

    private static String codificar(String valor) {
        return URLEncoder.encode(valor, StandardCharsets.UTF_8);
    }

    private static String texto(Object valor) {
        return valor instanceof String s ? s : null;
    }
}
