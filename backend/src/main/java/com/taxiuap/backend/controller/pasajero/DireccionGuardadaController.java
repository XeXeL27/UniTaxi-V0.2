package com.taxiuap.backend.controller.pasajero;

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
import com.taxiuap.backend.location.dto.DireccionGuardadaRequest;
import com.taxiuap.backend.location.dto.DireccionGuardadaResponse;
import com.taxiuap.backend.location.service.DireccionGuardadaService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Direcciones guardadas del pasajero autenticado. */
@RestController
@RequestMapping("/api/pasajero/direcciones")
@RequiredArgsConstructor
public class DireccionGuardadaController {

    private final DireccionGuardadaService direccionGuardadaService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<DireccionGuardadaResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(direccionGuardadaService.listar(UsuarioActual.idUsuario())));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<DireccionGuardadaResponse>> crear(
            @Valid @RequestBody DireccionGuardadaRequest request) {
        DireccionGuardadaResponse creada = direccionGuardadaService.crear(UsuarioActual.idUsuario(), request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Direccion guardada", creada));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<DireccionGuardadaResponse>> actualizar(
            @PathVariable Long id, @Valid @RequestBody DireccionGuardadaRequest request) {
        DireccionGuardadaResponse actualizada =
                direccionGuardadaService.actualizar(UsuarioActual.idUsuario(), id, request);
        return ResponseEntity.ok(ApiResponse.exito("Direccion actualizada", actualizada));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long id) {
        direccionGuardadaService.eliminar(UsuarioActual.idUsuario(), id);
        return ResponseEntity.ok(ApiResponse.exito("Direccion eliminada", null));
    }
}
