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

import com.taxiuap.backend.rating.dto.EtiquetaCalificacionRequest;
import com.taxiuap.backend.rating.dto.EtiquetaCalificacionResponse;
import com.taxiuap.backend.rating.service.EtiquetaCalificacionService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Administracion del catalogo de etiquetas de calificacion. */
@RestController
@RequestMapping("/api/admin/etiquetas-calificacion")
@RequiredArgsConstructor
public class EtiquetaCalificacionAdminController {

    private final EtiquetaCalificacionService etiquetaCalificacionService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<EtiquetaCalificacionResponse>>> listar(
            @RequestParam(defaultValue = "false") boolean incluirInactivos) {
        return ResponseEntity.ok(ApiResponse.exito(etiquetaCalificacionService.listar(incluirInactivos)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<EtiquetaCalificacionResponse>> obtener(@PathVariable Integer id) {
        return ResponseEntity.ok(ApiResponse.exito(etiquetaCalificacionService.obtener(id)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<EtiquetaCalificacionResponse>> crear(
            @Valid @RequestBody EtiquetaCalificacionRequest request) {
        EtiquetaCalificacionResponse creado = etiquetaCalificacionService.crear(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Etiqueta de calificacion creada", creado));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<EtiquetaCalificacionResponse>> actualizar(
            @PathVariable Integer id, @Valid @RequestBody EtiquetaCalificacionRequest request) {
        return ResponseEntity.ok(ApiResponse.exito(
                "Etiqueta de calificacion actualizada", etiquetaCalificacionService.actualizar(id, request)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Integer id) {
        etiquetaCalificacionService.eliminar(id);
        return ResponseEntity.ok(ApiResponse.exito("Etiqueta de calificacion eliminada", null));
    }
}
