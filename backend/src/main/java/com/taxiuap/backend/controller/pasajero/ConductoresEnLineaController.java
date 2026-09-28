package com.taxiuap.backend.controller.pasajero;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.location.dto.ConductorEnLineaResponse;
import com.taxiuap.backend.location.service.UbicacionService;
import com.taxiuap.backend.shared.response.ApiResponse;

import lombok.RequiredArgsConstructor;

/** Conductores libres en linea, para el mapa del pasajero. */
@RestController
@RequestMapping("/api/pasajero/conductores-en-linea")
@RequiredArgsConstructor
public class ConductoresEnLineaController {

    private final UbicacionService ubicacionService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<ConductorEnLineaResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(ubicacionService.conductoresLibres()));
    }
}
