package com.taxiuap.backend.controller.conductor;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.rating.dto.CalificacionesRecibidasResponse;
import com.taxiuap.backend.rating.service.CalificacionService;
import com.taxiuap.backend.shared.response.ApiResponse;

import lombok.RequiredArgsConstructor;

/** Calificaciones y comentarios que el conductor recibio de sus pasajeros. */
@RestController
@RequestMapping("/api/conductor/calificaciones")
@RequiredArgsConstructor
public class CalificacionConductorController {

    private final CalificacionService calificacionService;

    @GetMapping
    public ResponseEntity<ApiResponse<CalificacionesRecibidasResponse>> recibidas() {
        return ResponseEntity.ok(ApiResponse.exito(calificacionService.recibidasPorConductor()));
    }
}
