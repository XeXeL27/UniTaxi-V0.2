package com.taxiuap.backend.controller.pasajero;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.trip.dto.OfertaViajeResponse;
import com.taxiuap.backend.trip.dto.PrecioViajeResponse;
import com.taxiuap.backend.trip.dto.SolicitudViajeRequest;
import com.taxiuap.backend.trip.dto.SolicitudViajeResponse;
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.service.OfertaViajeService;
import com.taxiuap.backend.trip.service.SolicitudViajeService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Solicitud de viaje del pasajero autenticado y las ofertas que recibe sobre ella. */
@RestController
@RequestMapping("/api/pasajero/solicitudes")
@RequiredArgsConstructor
public class SolicitudViajeController {

    private final SolicitudViajeService solicitudViajeService;
    private final OfertaViajeService ofertaViajeService;

    @PostMapping
    public ResponseEntity<ApiResponse<SolicitudViajeResponse>> crear(
            @Valid @RequestBody SolicitudViajeRequest request) {
        SolicitudViajeResponse creada = solicitudViajeService.crear(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Solicitud creada", creada));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<SolicitudViajeResponse>>> listarPropias() {
        return ResponseEntity.ok(ApiResponse.exito(solicitudViajeService.listarPropias()));
    }

    /** Precio del viaje que se muestra antes de confirmar la solicitud. */
    @GetMapping("/precio")
    public ResponseEntity<ApiResponse<PrecioViajeResponse>> precio() {
        return ResponseEntity.ok(ApiResponse.exito(solicitudViajeService.precioVigente()));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<SolicitudViajeResponse>> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(solicitudViajeService.obtenerPropia(id)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> cancelar(@PathVariable Long id) {
        solicitudViajeService.cancelar(id);
        return ResponseEntity.ok(ApiResponse.exito("Solicitud cancelada", null));
    }

    @GetMapping("/{id}/ofertas")
    public ResponseEntity<ApiResponse<List<OfertaViajeResponse>>> listarOfertas(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(ofertaViajeService.listarDeSolicitud(id)));
    }

    @PostMapping("/ofertas/{idOferta}/aceptar")
    public ResponseEntity<ApiResponse<ViajeResponse>> aceptarOferta(@PathVariable Long idOferta) {
        ViajeResponse viaje = ofertaViajeService.aceptar(idOferta);
        return ResponseEntity.ok(ApiResponse.exito("Oferta aceptada", viaje));
    }
}
