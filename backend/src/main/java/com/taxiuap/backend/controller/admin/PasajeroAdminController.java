package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.identity.dto.PasajeroAdminResponse;
import com.taxiuap.backend.identity.service.GestionPasajeroService;
import com.taxiuap.backend.shared.response.ApiResponse;

import lombok.RequiredArgsConstructor;

/** Consulta de pasajeros desde el panel admin. */
@RestController
@RequestMapping("/api/admin/pasajeros")
@RequiredArgsConstructor
public class PasajeroAdminController {

    private final GestionPasajeroService gestionPasajeroService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<PasajeroAdminResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(gestionPasajeroService.listar()));
    }
}
