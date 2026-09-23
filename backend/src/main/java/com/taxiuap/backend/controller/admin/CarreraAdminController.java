package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.HttpStatus;
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

import com.taxiuap.backend.institution.dto.CarreraRequest;
import com.taxiuap.backend.institution.dto.CarreraResponse;
import com.taxiuap.backend.institution.service.CarreraService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Administracion del catalogo de carreras academicas. */
@RestController
@RequestMapping("/api/admin/carreras")
@RequiredArgsConstructor
public class CarreraAdminController {

    private final CarreraService carreraService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<CarreraResponse>>> listar(
            @RequestParam(defaultValue = "false") boolean incluirInactivos) {
        return ResponseEntity.ok(ApiResponse.exito(carreraService.listar(incluirInactivos)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<CarreraResponse>> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(carreraService.obtener(id)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<CarreraResponse>> crear(@Valid @RequestBody CarreraRequest request) {
        CarreraResponse creado = carreraService.crear(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Carrera creada", creado));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<CarreraResponse>> actualizar(
            @PathVariable Long id, @Valid @RequestBody CarreraRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Carrera actualizada", carreraService.actualizar(id, request)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long id) {
        carreraService.eliminar(id);
        return ResponseEntity.ok(ApiResponse.exito("Carrera eliminada", null));
    }
}
