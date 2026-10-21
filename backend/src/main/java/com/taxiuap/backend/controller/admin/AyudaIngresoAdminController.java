package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.communication.dto.AtenderAyudaIngresoRequest;
import com.taxiuap.backend.communication.dto.AyudaIngresoResponse;
import com.taxiuap.backend.communication.dto.RespuestaAyudaIngresoRequest;
import com.taxiuap.backend.communication.service.AyudaIngresoService;
import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Personas > Problemas de ingreso: mensajes de quienes no pueden ingresar (desde el registro o el login).
 * El administrador habilita la cuenta, la mantiene suspendida, le escribe un correo o lo da por atendido.
 */
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

    @PutMapping("/{id}/habilitar")
    public ResponseEntity<ApiResponse<AyudaIngresoResponse>> habilitar(@PathVariable Long id,
            @Valid @RequestBody RespuestaAyudaIngresoRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Cuenta habilitada",
                ayudaIngresoService.habilitar(id, request, UsuarioActual.obtener().orElseThrow())));
    }

    @PutMapping("/{id}/mantener-suspendida")
    public ResponseEntity<ApiResponse<AyudaIngresoResponse>> mantenerSuspendida(@PathVariable Long id,
            @Valid @RequestBody RespuestaAyudaIngresoRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("La cuenta sigue suspendida",
                ayudaIngresoService.mantenerSuspendida(id, request, UsuarioActual.obtener().orElseThrow())));
    }

    @PostMapping("/{id}/correo")
    public ResponseEntity<ApiResponse<AyudaIngresoResponse>> correo(@PathVariable Long id,
            @Valid @RequestBody RespuestaAyudaIngresoRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Correo enviado",
                ayudaIngresoService.enviarCorreo(id, request, UsuarioActual.obtener().orElseThrow())));
    }
}
