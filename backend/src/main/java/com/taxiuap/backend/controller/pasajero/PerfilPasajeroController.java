package com.taxiuap.backend.controller.pasajero;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.ActualizarPerfilRequest;
import com.taxiuap.backend.identity.dto.PerfilPasajeroResponse;
import com.taxiuap.backend.identity.service.PerfilPasajeroService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Perfil del pasajero autenticado. */
@RestController
@RequestMapping("/api/pasajero/perfil")
@RequiredArgsConstructor
public class PerfilPasajeroController {

    private final PerfilPasajeroService perfilPasajeroService;

    @GetMapping
    public ResponseEntity<ApiResponse<PerfilPasajeroResponse>> obtener() {
        return ResponseEntity.ok(ApiResponse.exito(perfilPasajeroService.obtener(UsuarioActual.idUsuario())));
    }

    @PutMapping
    public ResponseEntity<ApiResponse<PerfilPasajeroResponse>> actualizar(
            @Valid @RequestBody ActualizarPerfilRequest request) {
        PerfilPasajeroResponse actualizado = perfilPasajeroService.actualizar(UsuarioActual.idUsuario(), request);
        return ResponseEntity.ok(ApiResponse.exito("Perfil actualizado", actualizado));
    }
}
