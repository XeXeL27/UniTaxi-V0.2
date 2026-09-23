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
import com.taxiuap.backend.vehicle.dto.TipoVehiculoRequest;
import com.taxiuap.backend.vehicle.dto.TipoVehiculoResponse;
import com.taxiuap.backend.vehicle.service.TipoVehiculoService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Administracion del catalogo de tipos de vehiculo. */
@RestController
@RequestMapping("/api/admin/tipos-vehiculo")
@RequiredArgsConstructor
public class TipoVehiculoAdminController {

    private final TipoVehiculoService tipoVehiculoService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<TipoVehiculoResponse>>> listar(
            @RequestParam(defaultValue = "false") boolean incluirInactivos) {
        return ResponseEntity.ok(ApiResponse.exito(tipoVehiculoService.listar(incluirInactivos)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<TipoVehiculoResponse>> obtener(@PathVariable Integer id) {
        return ResponseEntity.ok(ApiResponse.exito(tipoVehiculoService.obtener(id)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<TipoVehiculoResponse>> crear(@Valid @RequestBody TipoVehiculoRequest request) {
        TipoVehiculoResponse creado = tipoVehiculoService.crear(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Tipo de vehiculo creado", creado));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<TipoVehiculoResponse>> actualizar(
            @PathVariable Integer id, @Valid @RequestBody TipoVehiculoRequest request) {
        return ResponseEntity.ok(
                ApiResponse.exito("Tipo de vehiculo actualizado", tipoVehiculoService.actualizar(id, request)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Integer id) {
        tipoVehiculoService.eliminar(id);
        return ResponseEntity.ok(ApiResponse.exito("Tipo de vehiculo eliminado", null));
    }
}
