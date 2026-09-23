package com.taxiuap.backend.controller.conductor;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.trip.dto.OfertaViajeRequest;
import com.taxiuap.backend.trip.dto.OfertaViajeResponse;
import com.taxiuap.backend.trip.dto.SolicitudViajeResponse;
import com.taxiuap.backend.trip.service.OfertaViajeService;
import com.taxiuap.backend.trip.service.SolicitudViajeService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Solicitudes de viaje disponibles para el conductor autenticado y sus ofertas. */
@RestController
@RequestMapping("/api/conductor")
@RequiredArgsConstructor
public class OfertaViajeController {

    private final SolicitudViajeService solicitudViajeService;
    private final OfertaViajeService ofertaViajeService;

    @GetMapping("/solicitudes")
    public ResponseEntity<ApiResponse<List<SolicitudViajeResponse>>> listarSolicitudesDisponibles() {
        return ResponseEntity.ok(ApiResponse.exito(solicitudViajeService.listarDisponiblesParaConductor()));
    }

    @PostMapping("/solicitudes/{idSolicitud}/ofertas")
    public ResponseEntity<ApiResponse<OfertaViajeResponse>> ofertar(
            @PathVariable Long idSolicitud, @Valid @RequestBody OfertaViajeRequest request) {
        OfertaViajeResponse creada = ofertaViajeService.ofertar(idSolicitud, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Oferta registrada", creada));
    }

    @GetMapping("/ofertas")
    public ResponseEntity<ApiResponse<List<OfertaViajeResponse>>> listarPropias() {
        return ResponseEntity.ok(ApiResponse.exito(ofertaViajeService.listarPropias()));
    }
}
