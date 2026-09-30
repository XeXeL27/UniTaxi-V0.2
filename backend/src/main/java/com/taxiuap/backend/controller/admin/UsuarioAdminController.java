package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.UsuarioAdminResponse;
import com.taxiuap.backend.identity.service.GestionUsuarioService;
import com.taxiuap.backend.shared.response.ApiResponse;

import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import com.taxiuap.backend.identity.service.FotoPerfilService;

import com.taxiuap.backend.identity.dto.CambiarEstadoUsuarioRequest;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Cuentas de usuario desde el panel admin. El alta se hace por /api/admin/personas/{id}/usuarios. */
@RestController
@RequestMapping("/api/admin/usuarios")
@RequiredArgsConstructor
public class UsuarioAdminController {

    private final GestionUsuarioService gestionUsuarioService;
    private final FotoPerfilService fotoPerfilService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<UsuarioAdminResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(gestionUsuarioService.listar()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long id) {
        gestionUsuarioService.eliminar(id, UsuarioActual.idUsuario());
        return ResponseEntity.ok(ApiResponse.exito("Usuario eliminado", null));
    }

    /** Suspende (S) o habilita (A) la cuenta; la suspendida sale de la app en su siguiente peticion. */
    @PutMapping("/{id}/estado")
    public ResponseEntity<ApiResponse<UsuarioAdminResponse>> cambiarEstado(
            @PathVariable Long id, @Valid @RequestBody CambiarEstadoUsuarioRequest request) {
        UsuarioAdminResponse usuario = gestionUsuarioService.cambiarEstado(id, request.estado(), UsuarioActual.idUsuario());
        return ResponseEntity.ok(ApiResponse.exito(
                request.estado() == EstadoRegistro.S ? "Cuenta suspendida" : "Cuenta habilitada", usuario));
    }

    /** Foto de perfil de una cuenta (404 si no tiene). */
    @GetMapping("/{id}/foto")
    public ResponseEntity<Resource> foto(@PathVariable Long id) {
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_JPEG)
                .cacheControl(CacheControl.noCache())
                .body(fotoPerfilService.leer(id));
    }
}
