package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.identity.dto.CambiarSituacionConductorRequest;
import com.taxiuap.backend.identity.dto.ConductorAdminResponse;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.service.GestionConductorService;
import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.vehicle.dto.DocumentoConductorAdminResponse;
import com.taxiuap.backend.vehicle.service.DocumentoConductorService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Revision administrativa de conductores. */
@RestController
@RequestMapping("/api/admin/conductores")
@RequiredArgsConstructor
public class ConductorAdminController {

    private final GestionConductorService gestionConductorService;
    private final DocumentoConductorService documentoConductorService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<ConductorAdminResponse>>> listar(
            @RequestParam(required = false) SituacionAprobacion situacion) {
        return ResponseEntity.ok(ApiResponse.exito(gestionConductorService.listar(situacion)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<ConductorAdminResponse>> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(gestionConductorService.obtener(id)));
    }

    @GetMapping("/{id}/documentos")
    public ResponseEntity<ApiResponse<List<DocumentoConductorAdminResponse>>> documentos(@PathVariable Long id) {
        gestionConductorService.obtener(id);
        return ResponseEntity.ok(ApiResponse.exito(documentoConductorService.listarDeConductor(id)));
    }

    @PutMapping("/{id}/situacion")
    public ResponseEntity<ApiResponse<ConductorAdminResponse>> cambiarSituacion(
            @PathVariable Long id, @Valid @RequestBody CambiarSituacionConductorRequest request) {
        ConductorAdminResponse actualizado = gestionConductorService.cambiarSituacion(id, request);
        return ResponseEntity.ok(ApiResponse.exito("Situacion del conductor actualizada", actualizado));
    }
}
