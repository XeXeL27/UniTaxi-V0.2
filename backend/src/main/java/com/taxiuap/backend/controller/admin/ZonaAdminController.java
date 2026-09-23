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

import com.taxiuap.backend.location.dto.ZonaRequest;
import com.taxiuap.backend.location.dto.ZonaResponse;
import com.taxiuap.backend.location.service.ZonaService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** CRUD administrativo de zonas geograficas de cobertura. */
@RestController
@RequestMapping("/api/admin/zonas")
@RequiredArgsConstructor
public class ZonaAdminController {

    private final ZonaService zonaService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<ZonaResponse>>> listar(
            @RequestParam(name = "incluirInactivos", defaultValue = "false") boolean incluirInactivos) {
        return ResponseEntity.ok(ApiResponse.exito(zonaService.listar(incluirInactivos)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<ZonaResponse>> buscarPorId(@PathVariable Integer id) {
        return ResponseEntity.ok(ApiResponse.exito(zonaService.buscarPorId(id)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<ZonaResponse>> crear(@Valid @RequestBody ZonaRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Zona creada", zonaService.crear(request)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<ZonaResponse>> actualizar(
            @PathVariable Integer id, @Valid @RequestBody ZonaRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Zona actualizada", zonaService.actualizar(id, request)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Integer id) {
        zonaService.eliminar(id);
        return ResponseEntity.ok(ApiResponse.exito("Zona eliminada", null));
    }
}
