package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.communication.dto.AtenderAyudaIngresoRequest;
import com.taxiuap.backend.communication.dto.AyudaIngresoResponse;
import com.taxiuap.backend.communication.service.AyudaIngresoService;
import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Personas > Problemas de ingreso: mensajes de quienes no pudieron recuperar su cuenta. */
@RestController
@RequestMapping("/api/admin/ayuda-ingreso")
@RequiredArgsConstructor
public class AyudaIngresoAdminController {

    private final AyudaIngresoService ayudaIngresoService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<AyudaIngresoResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(ayudaIngresoService.listar()));
    }

    /** Cuantos esperan respuesta: el contador del menu y la campana del panel. */
    @GetMapping("/pendientes")
    public ResponseEntity<ApiResponse<Long>> pendientes() {
        return ResponseEntity.ok(ApiResponse.exito(ayudaIngresoService.pendientes()));
    }

    @PutMapping("/{id}/atender")
    public ResponseEntity<ApiResponse<AyudaIngresoResponse>> atender(@PathVariable Long id,
            @Valid @RequestBody AtenderAyudaIngresoRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Mensaje actualizado",
                ayudaIngresoService.atender(id, request, UsuarioActual.obtener().orElseThrow())));
    }
}
