package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.location.dto.PosicionConductor;
import com.taxiuap.backend.location.service.UbicacionService;
import com.taxiuap.backend.shared.response.ApiResponse;

import lombok.RequiredArgsConstructor;

/**
 * Posiciones de los conductores para el mapa de flota del panel.
 *
 * Esta es la unica lectura REST del mapa y se llama una sola vez, al abrir la pantalla. Despues de
 * eso el panel se actualiza con el topic /topic/admin/conductores.
 *
 * El prefijo es /api/admin/mapa y no /api/admin/conductores a proposito: el controller de
 * conductores ya usa /api/admin/conductores/{id} y meter la flota ahi obligaria a depender de que
 * Spring prefiera el literal sobre la variable de ruta.
 */
@RestController
@RequestMapping("/api/admin/mapa")
@RequiredArgsConstructor
public class ConductorUbicacionAdminController {

    private final UbicacionService ubicacionService;

    @GetMapping("/flota")
    public ResponseEntity<ApiResponse<List<PosicionConductor>>> listarFlota() {
        return ResponseEntity.ok(ApiResponse.exito(ubicacionService.listaFlota()));
    }
}
