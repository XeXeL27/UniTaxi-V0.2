package com.taxiuap.backend.controller.admin;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.sistema.dto.CarpetaArchivosResponse;
import com.taxiuap.backend.sistema.dto.CrearCarpetaRequest;
import com.taxiuap.backend.sistema.dto.ListadoCarpetasResponse;
import com.taxiuap.backend.sistema.dto.RutaCarpetaRequest;
import com.taxiuap.backend.sistema.service.CarpetaArchivosService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Configuracion del sistema: carpeta raiz donde se guardan los archivos subidos. */
@RestController
@RequestMapping("/api/admin/sistema")
@RequiredArgsConstructor
public class SistemaAdminController {

    private final CarpetaArchivosService carpetaArchivosService;

    @GetMapping("/carpeta-archivos")
    public ResponseEntity<ApiResponse<CarpetaArchivosResponse>> carpeta() {
        return ResponseEntity.ok(ApiResponse.exito(carpetaArchivosService.actual()));
    }

    /** Cambia la carpeta raiz y mueve ahi todos los archivos existentes. */
    @PutMapping("/carpeta-archivos")
    public ResponseEntity<ApiResponse<CarpetaArchivosResponse>> cambiar(@Valid @RequestBody RutaCarpetaRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Carpeta de archivos cambiada", carpetaArchivosService.cambiar(request.ruta())));
    }

    /** Subcarpetas de una carpeta del servidor, para el explorador del panel. */
    @GetMapping("/carpetas")
    public ResponseEntity<ApiResponse<ListadoCarpetasResponse>> carpetas(@RequestParam(required = false) String ruta) {
        return ResponseEntity.ok(ApiResponse.exito(carpetaArchivosService.listar(ruta)));
    }

    @PostMapping("/carpetas")
    public ResponseEntity<ApiResponse<ListadoCarpetasResponse>> crearCarpeta(@Valid @RequestBody CrearCarpetaRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Carpeta creada", carpetaArchivosService.crear(request.padre(), request.nombre())));
    }
}
