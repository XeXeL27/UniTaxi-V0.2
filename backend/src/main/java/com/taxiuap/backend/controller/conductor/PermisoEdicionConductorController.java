package com.taxiuap.backend.controller.conductor;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.PermisoEdicionResponse;
import com.taxiuap.backend.identity.service.PermisoEdicionService;
import com.taxiuap.backend.shared.response.ApiResponse;

import lombok.RequiredArgsConstructor;

/** Permisos de edicion vigentes que el administrador le dio al conductor autenticado. */
@RestController
@RequestMapping("/api/conductor/permisos")
@RequiredArgsConstructor
public class PermisoEdicionConductorController {

    private final PermisoEdicionService permisoEdicionService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<PermisoEdicionResponse>>> vigentes() {
        return ResponseEntity.ok(ApiResponse.exito(permisoEdicionService.vigentesPorUsuario(UsuarioActual.idUsuario())));
    }
}
