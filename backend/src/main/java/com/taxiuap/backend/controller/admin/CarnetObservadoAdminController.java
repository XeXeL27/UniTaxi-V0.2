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
import com.taxiuap.backend.identity.dto.CarnetObservadoResponse;
import com.taxiuap.backend.identity.dto.RechazoCarnetRequest;
import com.taxiuap.backend.identity.dto.RevisionCarnetRequest;
import com.taxiuap.backend.identity.service.RevisionCarnetService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Carnets que esperan revision (OBSERVADO): el administrador compara los datos con las fotos, los
 * corrige y aprueba (salen las credenciales) o rechaza (se elimina el registro). Las fotos se piden a
 * /api/admin/usuarios/{idUsuario}/carnet/{lado}.
 */
@RestController
@RequestMapping("/api/admin/carnets-observados")
@RequiredArgsConstructor
public class CarnetObservadoAdminController {

    private final RevisionCarnetService revisionCarnetService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<CarnetObservadoResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(revisionCarnetService.listar()));
    }

    @PutMapping("/{idPersona}/aprobar")
    public ResponseEntity<ApiResponse<CarnetObservadoResponse>> aprobar(@PathVariable Long idPersona,
            @Valid @RequestBody RevisionCarnetRequest datos) {
        return ResponseEntity.ok(ApiResponse.exito("Datos aprobados: se enviaron las credenciales a su correo",
                revisionCarnetService.aprobar(idPersona, datos)));
    }

    @PutMapping("/{idPersona}/rechazar")
    public ResponseEntity<ApiResponse<Void>> rechazar(@PathVariable Long idPersona,
            @Valid @RequestBody RechazoCarnetRequest datos) {
        revisionCarnetService.rechazar(idPersona, datos.motivo(), UsuarioActual.idUsuario());
        return ResponseEntity.ok(ApiResponse.exito("Registro rechazado: se aviso a la persona por correo", null));
    }
}
