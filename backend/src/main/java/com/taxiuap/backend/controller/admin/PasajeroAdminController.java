package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.identity.dto.PasajeroAdminResponse;
import com.taxiuap.backend.identity.service.GestionPasajeroService;
import com.taxiuap.backend.shared.response.ApiResponse;

import com.taxiuap.backend.identity.dto.PerfilPasajeroResponse;
import com.taxiuap.backend.identity.service.PerfilPasajeroService;
import com.taxiuap.backend.location.dto.DireccionGuardadaResponse;
import com.taxiuap.backend.location.service.DireccionGuardadaService;
import com.taxiuap.backend.rating.dto.CalificacionResponse;
import com.taxiuap.backend.rating.service.CalificacionService;
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.service.ViajeService;
import org.springframework.web.bind.annotation.PathVariable;

import lombok.RequiredArgsConstructor;

/** Consulta de pasajeros desde el panel admin. */
@RestController
@RequestMapping("/api/admin/pasajeros")
@RequiredArgsConstructor
public class PasajeroAdminController {

    private final GestionPasajeroService gestionPasajeroService;
    private final PerfilPasajeroService perfilPasajeroService;
    private final ViajeService viajeService;
    private final DireccionGuardadaService direccionGuardadaService;
    private final CalificacionService calificacionService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<PasajeroAdminResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(gestionPasajeroService.listar()));
    }

    /** Lo que ve el pasajero en su perfil. */
    @GetMapping("/{id}/perfil")
    public ResponseEntity<ApiResponse<PerfilPasajeroResponse>> perfil(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(perfilPasajeroService.obtenerPorPasajero(id)));
    }

    @GetMapping("/{id}/viajes")
    public ResponseEntity<ApiResponse<List<ViajeResponse>>> viajes(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.listarPorPasajero(id)));
    }

    /** Lugares favoritos del pasajero. */
    @GetMapping("/{id}/direcciones")
    public ResponseEntity<ApiResponse<List<DireccionGuardadaResponse>>> direcciones(@PathVariable Long id) {
        Long idUsuario = perfilPasajeroService.obtenerPorPasajero(id).idUsuario();
        return ResponseEntity.ok(ApiResponse.exito(direccionGuardadaService.listar(idUsuario)));
    }

    /** Calificaciones que el pasajero dio a sus conductores. */
    @GetMapping("/{id}/calificaciones")
    public ResponseEntity<ApiResponse<List<CalificacionResponse>>> calificaciones(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(calificacionService.dadasPorPasajero(id)));
    }
}
