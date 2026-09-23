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

import com.taxiuap.backend.pricing.dto.TarifaRequest;
import com.taxiuap.backend.pricing.dto.TarifaResponse;
import com.taxiuap.backend.pricing.service.TarifaService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** CRUD administrativo de tarifas por categoria de servicio y zona. */
@RestController
@RequestMapping("/api/admin/tarifas")
@RequiredArgsConstructor
public class TarifaAdminController {

    private final TarifaService tarifaService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<TarifaResponse>>> listar(
            @RequestParam(name = "idZona", required = false) Integer idZona,
            @RequestParam(name = "idCategoriaServicio", required = false) Integer idCategoriaServicio,
            @RequestParam(name = "incluirInactivos", defaultValue = "false") boolean incluirInactivos) {
        return ResponseEntity.ok(
                ApiResponse.exito(tarifaService.listar(idZona, idCategoriaServicio, incluirInactivos)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<TarifaResponse>> buscarPorId(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(tarifaService.buscarPorId(id)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<TarifaResponse>> crear(@Valid @RequestBody TarifaRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Tarifa creada", tarifaService.crear(request)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<TarifaResponse>> actualizar(
            @PathVariable Long id, @Valid @RequestBody TarifaRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Tarifa actualizada", tarifaService.actualizar(id, request)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long id) {
        tarifaService.eliminar(id);
        return ResponseEntity.ok(ApiResponse.exito("Tarifa eliminada", null));
    }
}
