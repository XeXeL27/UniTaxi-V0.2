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

import com.taxiuap.backend.pricing.dto.DescuentoRequest;
import com.taxiuap.backend.pricing.dto.DescuentoResponse;
import com.taxiuap.backend.pricing.service.DescuentoService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** CRUD administrativo de cupones y promociones de descuento. */
@RestController
@RequestMapping("/api/admin/descuentos")
@RequiredArgsConstructor
public class DescuentoAdminController {

    private final DescuentoService descuentoService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<DescuentoResponse>>> listar(
            @RequestParam(name = "incluirInactivos", defaultValue = "false") boolean incluirInactivos) {
        return ResponseEntity.ok(ApiResponse.exito(descuentoService.listar(incluirInactivos)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<DescuentoResponse>> buscarPorId(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(descuentoService.buscarPorId(id)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<DescuentoResponse>> crear(@Valid @RequestBody DescuentoRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Descuento creado", descuentoService.crear(request)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<DescuentoResponse>> actualizar(
            @PathVariable Long id, @Valid @RequestBody DescuentoRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Descuento actualizado", descuentoService.actualizar(id, request)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long id) {
        descuentoService.eliminar(id);
        return ResponseEntity.ok(ApiResponse.exito("Descuento eliminado", null));
    }
}
