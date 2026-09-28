package com.taxiuap.backend.controller.auth;

import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.dto.LoginRequest;
import com.taxiuap.backend.identity.dto.RefreshRequest;
import com.taxiuap.backend.identity.dto.RegistroConductorRequest;
import com.taxiuap.backend.identity.dto.RegistroPasajeroRequest;
import com.taxiuap.backend.identity.dto.TokenResponse;
import com.taxiuap.backend.identity.service.AutenticacionService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Endpoints publicos de autenticacion: registro, login y renovacion de tokens. */
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AutenticacionController {

    private final AutenticacionService autenticacionService;

    @PostMapping("/registro/pasajero")
    public ResponseEntity<ApiResponse<TokenResponse>> registrarPasajero(
            @Valid @RequestBody RegistroPasajeroRequest datos) {
        TokenResponse token = autenticacionService.registrarPasajero(datos);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Registro exitoso", token));
    }

    /**
     * Registro publico de conductor con el formulario. Multipart: "datos" (JSON) y un PDF por parte
     * con el tipo de documento como nombre (CI y LICENCIA obligatorios). Queda PENDIENTE de revision.
     */
    @PostMapping(value = "/registro/conductor", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<TokenResponse>> registrarConductor(
            @Valid @RequestPart("datos") RegistroConductorRequest datos,
            @RequestParam Map<String, MultipartFile> archivos) {
        TokenResponse token = autenticacionService.registrarConductor(datos, archivos);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Registro enviado a revision", token));
    }

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<TokenResponse>> login(@Valid @RequestBody LoginRequest datos) {
        TokenResponse token = autenticacionService.login(datos);
        return ResponseEntity.ok(ApiResponse.exito("Sesion iniciada", token));
    }

    /** Tipos de cuenta (PASAJERO, CONDUCTOR, ADMIN) que tiene la persona con estas credenciales. */
    @PostMapping("/cuentas")
    public ResponseEntity<ApiResponse<List<String>>> cuentas(@Valid @RequestBody LoginRequest datos) {
        return ResponseEntity.ok(ApiResponse.exito(autenticacionService.cuentas(datos.usuario(), datos.password())));
    }

    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<TokenResponse>> refrescar(@Valid @RequestBody RefreshRequest datos) {
        TokenResponse token = autenticacionService.refrescar(datos);
        return ResponseEntity.ok(ApiResponse.exito(token));
    }
}
