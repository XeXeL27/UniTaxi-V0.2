package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.institution.dto.ResolverVerificacionRequest;
import com.taxiuap.backend.institution.dto.VerificacionPendienteResponse;
import com.taxiuap.backend.institution.service.VerificacionEstudianteService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Revision administrativa de matriculas estudiantiles pendientes de verificacion. */
@RestController
@RequestMapping("/api/admin/verificaciones-estudiantiles")
@RequiredArgsConstructor
public class VerificacionEstudiantilAdminController {

    private final VerificacionEstudianteService verificacionEstudianteService;

    @GetMapping("/pendientes")
    public ResponseEntity<ApiResponse<List<VerificacionPendienteResponse>>> listarPendientes() {
        return ResponseEntity.ok(ApiResponse.exito(verificacionEstudianteService.listarPendientes()));
    }

    @PutMapping("/{idMatricula}")
    public ResponseEntity<ApiResponse<Void>> resolver(
            @PathVariable Long idMatricula, @Valid @RequestBody ResolverVerificacionRequest request) {
        verificacionEstudianteService.resolver(idMatricula, request, UsuarioActual.idUsuario());
        return ResponseEntity.ok(ApiResponse.exito("Verificacion resuelta", null));
    }
}
