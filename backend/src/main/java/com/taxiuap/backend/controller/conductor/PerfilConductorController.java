package com.taxiuap.backend.controller.conductor;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.ActualizarPerfilConductorRequest;
import com.taxiuap.backend.identity.dto.PerfilConductorResponse;
import com.taxiuap.backend.identity.service.PerfilConductorService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Perfil del conductor autenticado. */
@RestController
@RequestMapping("/api/conductor/perfil")
@RequiredArgsConstructor
public class PerfilConductorController {

    private final PerfilConductorService perfilConductorService;

    @GetMapping
    public ResponseEntity<ApiResponse<PerfilConductorResponse>> obtener() {
        return ResponseEntity.ok(ApiResponse.exito(perfilConductorService.obtener(UsuarioActual.idUsuario())));
    }

    @PutMapping
    public ResponseEntity<ApiResponse<PerfilConductorResponse>> actualizar(
            @Valid @RequestBody ActualizarPerfilConductorRequest request) {
        PerfilConductorResponse actualizado = perfilConductorService.actualizar(UsuarioActual.idUsuario(), request);
        return ResponseEntity.ok(ApiResponse.exito("Perfil actualizado", actualizado));
    }
}
