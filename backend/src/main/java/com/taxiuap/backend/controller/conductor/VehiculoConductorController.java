package com.taxiuap.backend.controller.conductor;

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
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.vehicle.dto.VehiculoRequest;
import com.taxiuap.backend.vehicle.dto.VehiculoResponse;
import com.taxiuap.backend.vehicle.service.VehiculoService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Vehiculos del conductor autenticado. */
@RestController
@RequestMapping("/api/conductor/vehiculos")
@RequiredArgsConstructor
public class VehiculoConductorController {

    private final VehiculoService vehiculoService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<VehiculoResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(vehiculoService.listar(UsuarioActual.idUsuario())));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<VehiculoResponse>> crear(@Valid @RequestBody VehiculoRequest request) {
        VehiculoResponse creado = vehiculoService.crear(UsuarioActual.idUsuario(), request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Vehiculo registrado", creado));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<VehiculoResponse>> actualizar(
            @PathVariable Long id, @Valid @RequestBody VehiculoRequest request) {
        VehiculoResponse actualizado = vehiculoService.actualizar(UsuarioActual.idUsuario(), id, request);
        return ResponseEntity.ok(ApiResponse.exito("Vehiculo actualizado", actualizado));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long id) {
        vehiculoService.eliminar(UsuarioActual.idUsuario(), id);
        return ResponseEntity.ok(ApiResponse.exito("Vehiculo dado de baja", null));
    }
}
