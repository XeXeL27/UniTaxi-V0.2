package com.taxiuap.backend.controller.cuenta;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.CambiarRolRequest;
import com.taxiuap.backend.identity.dto.TokenResponse;
import com.taxiuap.backend.identity.service.AutenticacionService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Cambio de modo en la app movil (pasajero o conductor) para quien tiene las dos cuentas. Queda
 * fuera de /api/auth a proposito: exige una sesion iniciada.
 */
@RestController
@RequestMapping("/api/cuenta")
@RequiredArgsConstructor
public class CambioRolController {

    private final AutenticacionService autenticacionService;

    @PostMapping("/cambiar-rol")
    public ResponseEntity<ApiResponse<TokenResponse>> cambiarRol(@Valid @RequestBody CambiarRolRequest request) {
        TokenResponse token = autenticacionService.cambiarRol(UsuarioActual.idUsuario(), request.rol());
        return ResponseEntity.ok(ApiResponse.exito("Modo cambiado", token));
    }
}
