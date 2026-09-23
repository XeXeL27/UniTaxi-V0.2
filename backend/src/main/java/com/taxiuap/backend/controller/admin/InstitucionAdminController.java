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

import com.taxiuap.backend.institution.dto.InstitucionRequest;
import com.taxiuap.backend.institution.dto.InstitucionResponse;
import com.taxiuap.backend.institution.service.InstitucionService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Administracion del catalogo de instituciones educativas. */
@RestController
@RequestMapping("/api/admin/instituciones")
@RequiredArgsConstructor
public class InstitucionAdminController {

    private final InstitucionService institucionService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<InstitucionResponse>>> listar(
            @RequestParam(defaultValue = "false") boolean incluirInactivos) {
        return ResponseEntity.ok(ApiResponse.exito(institucionService.listar(incluirInactivos)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<InstitucionResponse>> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(institucionService.obtener(id)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<InstitucionResponse>> crear(@Valid @RequestBody InstitucionRequest request) {
        InstitucionResponse creado = institucionService.crear(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Institucion creada", creado));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<InstitucionResponse>> actualizar(
            @PathVariable Long id, @Valid @RequestBody InstitucionRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Institucion actualizada", institucionService.actualizar(id, request)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long id) {
        institucionService.eliminar(id);
        return ResponseEntity.ok(ApiResponse.exito("Institucion eliminada", null));
    }
}
