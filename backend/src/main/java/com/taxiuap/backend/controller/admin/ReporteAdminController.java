package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.communication.dto.ReporteResponse;
import com.taxiuap.backend.communication.dto.ResolverReporteRequest;
import com.taxiuap.backend.communication.service.ReporteService;
import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Reportes de incidentes DELIVERY, visibles exclusivamente para administradores. */
@RestController
@RequestMapping("/api/admin/reportes")
@RequiredArgsConstructor
public class ReporteAdminController {

    private final ReporteService reporteService;
    private final AlmacenamientoArchivos almacenamientoArchivos;

    @GetMapping
    public ResponseEntity<ApiResponse<List<ReporteResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(reporteService.listar()));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<ReporteResponse>> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(reporteService.obtener(id)));
    }

    @PutMapping("/{id}/resolver")
    public ResponseEntity<ApiResponse<ReporteResponse>> resolver(@PathVariable Long id,
            @Valid @RequestBody ResolverReporteRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Reporte actualizado",
                reporteService.resolver(id, request, UsuarioActual.obtener().orElseThrow())));
    }

    @GetMapping("/{id}/foto")
    public ResponseEntity<Resource> foto(@PathVariable Long id) {
        ReporteResponse reporte = reporteService.obtener(id);
        Resource recurso = almacenamientoArchivos.leer(reporte.fotoFallaUrl());
        return ResponseEntity.ok().cacheControl(CacheControl.noCache())
                .contentType(MediaType.IMAGE_JPEG).body(recurso);
    }
}
