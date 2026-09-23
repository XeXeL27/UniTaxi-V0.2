package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.pricing.dto.ReglaDescuentoRequest;
import com.taxiuap.backend.pricing.dto.ReglaDescuentoResponse;
import com.taxiuap.backend.pricing.service.ReglaDescuentoService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** CRUD administrativo de reglas de descuento estudiantil. */
@RestController
@RequestMapping("/api/admin/reglas-descuento")
@RequiredArgsConstructor
public class ReglaDescuentoAdminController {

    private final ReglaDescuentoService reglaDescuentoService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<ReglaDescuentoResponse>>> listar(
            @RequestParam(name = "incluirInactivos", defaultValue = "false") boolean incluirInactivos) {
        return ResponseEntity.ok(ApiResponse.exito(reglaDescuentoService.listar(incluirInactivos)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<ReglaDescuentoResponse>> buscarPorId(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(reglaDescuentoService.buscarPorId(id)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<ReglaDescuentoResponse>> crear(
            @Valid @RequestBody ReglaDescuentoRequest request) {
        return ResponseEntity.ok(
                ApiResponse.exito("Regla de descuento creada", reglaDescuentoService.crear(request)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<ReglaDescuentoResponse>> actualizar(
            @PathVariable Long id, @Valid @RequestBody ReglaDescuentoRequest request) {
        return ResponseEntity.ok(
                ApiResponse.exito("Regla de descuento actualizada", reglaDescuentoService.actualizar(id, request)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long id) {
        reglaDescuentoService.eliminar(id);
        return ResponseEntity.ok(ApiResponse.exito("Regla de descuento eliminada", null));
    }
}
