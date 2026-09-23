package com.taxiuap.backend.controller.conductor;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.vehicle.dto.DocumentoConductorRequest;
import com.taxiuap.backend.vehicle.dto.DocumentoConductorResponse;
import com.taxiuap.backend.vehicle.service.DocumentoConductorService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Documentos del conductor autenticado. */
@RestController
@RequestMapping("/api/conductor/documentos")
@RequiredArgsConstructor
public class DocumentoConductorController {

    private final DocumentoConductorService documentoConductorService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<DocumentoConductorResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(documentoConductorService.listar(UsuarioActual.idUsuario())));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<DocumentoConductorResponse>> crear(
            @Valid @RequestBody DocumentoConductorRequest request) {
        DocumentoConductorResponse creado = documentoConductorService.crear(UsuarioActual.idUsuario(), request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Documento subido", creado));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<DocumentoConductorResponse>> actualizar(
            @PathVariable Long id, @Valid @RequestBody DocumentoConductorRequest request) {
        DocumentoConductorResponse actualizado =
                documentoConductorService.actualizar(UsuarioActual.idUsuario(), id, request);
        return ResponseEntity.ok(ApiResponse.exito("Documento actualizado", actualizado));
    }
}
