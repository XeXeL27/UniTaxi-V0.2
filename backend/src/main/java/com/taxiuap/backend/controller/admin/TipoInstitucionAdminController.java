package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.institution.dto.TipoInstitucionRequest;
import com.taxiuap.backend.institution.dto.TipoInstitucionResponse;
import com.taxiuap.backend.institution.service.TipoInstitucionService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Administracion del catalogo de tipos de institucion. */
@RestController
@RequestMapping("/api/admin/tipos-institucion")
@RequiredArgsConstructor
public class TipoInstitucionAdminController {

    private final TipoInstitucionService tipoInstitucionService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<TipoInstitucionResponse>>> listar(
            @RequestParam(defaultValue = "false") boolean incluirInactivos) {
        return ResponseEntity.ok(ApiResponse.exito(tipoInstitucionService.listar(incluirInactivos)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<TipoInstitucionResponse>> obtener(@PathVariable Integer id) {
        return ResponseEntity.ok(ApiResponse.exito(tipoInstitucionService.obtener(id)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<TipoInstitucionResponse>> crear(
            @Valid @RequestBody TipoInstitucionRequest request) {
        TipoInstitucionResponse creado = tipoInstitucionService.crear(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.exito("Tipo de institucion creado", creado));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<TipoInstitucionResponse>> actualizar(
            @PathVariable Integer id, @Valid @RequestBody TipoInstitucionRequest request) {
        return ResponseEntity.ok(
                ApiResponse.exito("Tipo de institucion actualizado", tipoInstitucionService.actualizar(id, request)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Integer id) {
        tipoInstitucionService.eliminar(id);
        return ResponseEntity.ok(ApiResponse.exito("Tipo de institucion eliminado", null));
    }
}
