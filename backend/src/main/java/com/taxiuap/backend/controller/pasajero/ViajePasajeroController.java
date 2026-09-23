package com.taxiuap.backend.controller.pasajero;

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
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.service.ViajeService;

import lombok.RequiredArgsConstructor;

/** Viajes del pasajero autenticado. */
@RestController
@RequestMapping("/api/pasajero/viajes")
@RequiredArgsConstructor
public class ViajePasajeroController {

    private final ViajeService viajeService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<ViajeResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.listarDelPasajero()));
    }

    @GetMapping("/en-curso")
    public ResponseEntity<ApiResponse<ViajeResponse>> enCurso() {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.enCurso().orElse(null)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<ViajeResponse>> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.obtener(id)));
    }

    @PostMapping("/{id}/cancelar")
    public ResponseEntity<ApiResponse<ViajeResponse>> cancelar(
            @PathVariable Long id, @RequestBody(required = false) CancelarViajeRequest request) {
        ViajeResponse cancelado = viajeService.cancelar(id, request);
        return ResponseEntity.ok(ApiResponse.exito("Viaje cancelado", cancelado));
    }
}
