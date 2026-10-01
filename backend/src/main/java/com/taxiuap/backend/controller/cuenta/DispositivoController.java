package com.taxiuap.backend.controller.cuenta;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.DispositivoRequest;
import com.taxiuap.backend.identity.service.DispositivoService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Telefono de la cuenta para las notificaciones push (FCM). */
@RestController
@RequestMapping("/api/cuenta/dispositivo")
@RequiredArgsConstructor
public class DispositivoController {

    private final DispositivoService dispositivoService;

    @PostMapping
    public ResponseEntity<ApiResponse<Void>> registrar(@Valid @RequestBody DispositivoRequest request) {
        dispositivoService.registrar(UsuarioActual.idUsuario(), request.token(), request.plataforma());
        return ResponseEntity.ok(ApiResponse.exito("Dispositivo registrado", null));
    }

    /** Al cerrar sesion: ese telefono deja de recibir los avisos de esta cuenta. */
    @PostMapping("/baja")
    public ResponseEntity<ApiResponse<Void>> baja(@Valid @RequestBody DispositivoRequest request) {
        dispositivoService.darDeBaja(UsuarioActual.idUsuario(), request.token());
        return ResponseEntity.ok(ApiResponse.exito("Dispositivo dado de baja", null));
    }
}
