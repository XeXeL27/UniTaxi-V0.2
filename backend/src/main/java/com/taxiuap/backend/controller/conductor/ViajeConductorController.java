package com.taxiuap.backend.controller.conductor;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.trip.dto.CancelarViajeRequest;
import com.taxiuap.backend.trip.dto.FinalizarViajeRequest;
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.service.ViajeService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Viajes del conductor autenticado. */
@RestController
@RequestMapping("/api/conductor/viajes")
@RequiredArgsConstructor
public class ViajeConductorController {

    private final ViajeService viajeService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<ViajeResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.listarDelConductor()));
    }

    @GetMapping("/en-curso")
    public ResponseEntity<ApiResponse<ViajeResponse>> enCurso() {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.enCurso().orElse(null)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<ViajeResponse>> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.obtener(id)));
    }

    @PostMapping("/{id}/en-camino")
    public ResponseEntity<ApiResponse<ViajeResponse>> enCamino(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito("El conductor esta en camino", viajeService.enCamino(id)));
    }

    @PostMapping("/{id}/llegue")
    public ResponseEntity<ApiResponse<ViajeResponse>> llegue(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito("El conductor llego", viajeService.llegue(id)));
    }

    @PostMapping("/{id}/iniciar")
    public ResponseEntity<ApiResponse<ViajeResponse>> iniciar(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito("Viaje iniciado", viajeService.iniciar(id)));
    }

    @PostMapping("/{id}/finalizar")
    public ResponseEntity<ApiResponse<ViajeResponse>> finalizar(
            @PathVariable Long id, @Valid @RequestBody FinalizarViajeRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Viaje finalizado", viajeService.finalizar(id, request)));
    }

    @PostMapping("/{id}/cancelar")
    public ResponseEntity<ApiResponse<ViajeResponse>> cancelar(
            @PathVariable Long id, @RequestBody(required = false) CancelarViajeRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Viaje cancelado", viajeService.cancelar(id, request)));
    }
}
