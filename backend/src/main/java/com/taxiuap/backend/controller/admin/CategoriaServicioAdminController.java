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

import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.vehicle.dto.CategoriaServicioRequest;
import com.taxiuap.backend.vehicle.dto.CategoriaServicioResponse;
import com.taxiuap.backend.vehicle.service.CategoriaServicioService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Administracion del catalogo de categorias de servicio. */
@RestController
@RequestMapping("/api/admin/categorias-servicio")
@RequiredArgsConstructor
public class CategoriaServicioAdminController {

    private final CategoriaServicioService categoriaServicioService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<CategoriaServicioResponse>>> listar(
            @RequestParam(defaultValue = "false") boolean incluirInactivos) {
        return ResponseEntity.ok(ApiResponse.exito(categoriaServicioService.listar(incluirInactivos)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<CategoriaServicioResponse>> obtener(@PathVariable Integer id) {
        return ResponseEntity.ok(ApiResponse.exito(categoriaServicioService.obtener(id)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<CategoriaServicioResponse>> crear(
            @Valid @RequestBody CategoriaServicioRequest request) {
        CategoriaServicioResponse creado = categoriaServicioService.crear(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Categoria de servicio creada", creado));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<CategoriaServicioResponse>> actualizar(
            @PathVariable Integer id, @Valid @RequestBody CategoriaServicioRequest request) {
        return ResponseEntity.ok(
                ApiResponse.exito("Categoria de servicio actualizada", categoriaServicioService.actualizar(id, request)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Integer id) {
        categoriaServicioService.eliminar(id);
        return ResponseEntity.ok(ApiResponse.exito("Categoria de servicio eliminada", null));
    }
}
