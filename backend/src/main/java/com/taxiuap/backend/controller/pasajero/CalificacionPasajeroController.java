package com.taxiuap.backend.controller.pasajero;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.rating.dto.CalificacionRequest;
import com.taxiuap.backend.rating.dto.CalificacionResponse;
import com.taxiuap.backend.rating.service.CalificacionService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** El pasajero califica al conductor de un viaje completado. */
@RestController
@RequestMapping("/api/pasajero/viajes")
@RequiredArgsConstructor
public class CalificacionPasajeroController {

    private final CalificacionService calificacionService;

    @PostMapping("/{idViaje}/calificacion")
    public ResponseEntity<ApiResponse<CalificacionResponse>> calificar(
            @PathVariable Long idViaje, @Valid @RequestBody CalificacionRequest request) {
        CalificacionResponse creada = calificacionService.calificarConductor(idViaje, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Gracias por calificar", creada));
    }
}
