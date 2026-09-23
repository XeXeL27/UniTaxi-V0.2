package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.UsuarioAdminResponse;
import com.taxiuap.backend.identity.service.GestionUsuarioService;
import com.taxiuap.backend.shared.response.ApiResponse;

import lombok.RequiredArgsConstructor;

/** Cuentas de usuario desde el panel admin. El alta se hace por /api/admin/personas/{id}/usuarios. */
@RestController
@RequestMapping("/api/admin/usuarios")
@RequiredArgsConstructor
public class UsuarioAdminController {

    private final GestionUsuarioService gestionUsuarioService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<UsuarioAdminResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(gestionUsuarioService.listar()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long id) {
        gestionUsuarioService.eliminar(id, UsuarioActual.idUsuario());
        return ResponseEntity.ok(ApiResponse.exito("Usuario eliminado", null));
    }
}
