package com.taxiuap.backend.controller.cuenta;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.CambiarContrasenaRequest;
import com.taxiuap.backend.identity.service.AutenticacionService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Cambio de contrasena de la cuenta con la que se inicio sesion (pasajero, conductor o admin). */
@RestController
@RequestMapping("/api/cuenta")
@RequiredArgsConstructor
public class ContrasenaController {

    private final AutenticacionService autenticacionService;

    @PostMapping("/contrasena")
    public ResponseEntity<ApiResponse<Void>> cambiar(@Valid @RequestBody CambiarContrasenaRequest request) {
        autenticacionService.cambiarContrasena(UsuarioActual.idUsuario(), request);
        return ResponseEntity.ok(ApiResponse.exito("Contrasena actualizada", null));
    }
}
