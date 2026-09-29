package com.taxiuap.backend.controller.pasajero;

import java.util.Map;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.RegistroConductorEstadoResponse;
import com.taxiuap.backend.identity.dto.RegistroConductorPasajeroRequest;
import com.taxiuap.backend.identity.service.RegistroConductorPasajeroService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** El pasajero se registra como conductor desde Mas; queda en revision hasta que el admin lo apruebe. */
@RestController
@RequestMapping("/api/pasajero/registro-conductor")
@RequiredArgsConstructor
public class RegistroConductorPasajeroController {

    private final RegistroConductorPasajeroService registroService;

    @GetMapping
    public ResponseEntity<ApiResponse<RegistroConductorEstadoResponse>> estado() {
        return ResponseEntity.ok(ApiResponse.exito(registroService.estado(UsuarioActual.idUsuario())));
    }

    /** Multipart: "datos" (JSON), un PDF por tipo de documento (CI y LICENCIA obligatorios) y QR1..QR3. */
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<RegistroConductorEstadoResponse>> registrar(
            @Valid @RequestPart("datos") RegistroConductorPasajeroRequest datos,
            @RequestParam Map<String, MultipartFile> archivos) {
        return ResponseEntity.ok(ApiResponse.exito("Registro de conductor enviado a revision",
                registroService.registrar(UsuarioActual.idUsuario(), datos, archivos)));
    }
}
