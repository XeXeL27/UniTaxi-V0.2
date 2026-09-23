package com.taxiuap.backend.controller.auth;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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

    @PostMapping("/registro/conductor")
    public ResponseEntity<ApiResponse<TokenResponse>> registrarConductor(
            @Valid @RequestBody RegistroConductorRequest datos) {
        TokenResponse token = autenticacionService.registrarConductor(datos);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Registro exitoso", token));
    }

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<TokenResponse>> login(@Valid @RequestBody LoginRequest datos) {
        TokenResponse token = autenticacionService.login(datos);
        return ResponseEntity.ok(ApiResponse.exito("Sesion iniciada", token));
    }

    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<TokenResponse>> refrescar(@Valid @RequestBody RefreshRequest datos) {
        TokenResponse token = autenticacionService.refrescar(datos);
        return ResponseEntity.ok(ApiResponse.exito(token));
    }
}
