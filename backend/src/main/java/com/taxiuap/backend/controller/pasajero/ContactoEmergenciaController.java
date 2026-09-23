package com.taxiuap.backend.controller.pasajero;

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
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.communication.dto.ContactoEmergenciaRequest;
import com.taxiuap.backend.communication.dto.ContactoEmergenciaResponse;
import com.taxiuap.backend.communication.service.ContactoEmergenciaService;
import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Contactos de emergencia del usuario autenticado. */
@RestController
@RequestMapping("/api/pasajero/contactos-emergencia")
@RequiredArgsConstructor
public class ContactoEmergenciaController {

    private final ContactoEmergenciaService contactoEmergenciaService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<ContactoEmergenciaResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(contactoEmergenciaService.listar(UsuarioActual.idUsuario())));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<ContactoEmergenciaResponse>> crear(
            @Valid @RequestBody ContactoEmergenciaRequest request) {
        ContactoEmergenciaResponse creado = contactoEmergenciaService.crear(UsuarioActual.idUsuario(), request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Contacto de emergencia creado", creado));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<ContactoEmergenciaResponse>> actualizar(
            @PathVariable Long id, @Valid @RequestBody ContactoEmergenciaRequest request) {
        ContactoEmergenciaResponse actualizado =
                contactoEmergenciaService.actualizar(UsuarioActual.idUsuario(), id, request);
        return ResponseEntity.ok(ApiResponse.exito("Contacto de emergencia actualizado", actualizado));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long id) {
        contactoEmergenciaService.eliminar(UsuarioActual.idUsuario(), id);
        return ResponseEntity.ok(ApiResponse.exito("Contacto de emergencia eliminado", null));
    }
}
