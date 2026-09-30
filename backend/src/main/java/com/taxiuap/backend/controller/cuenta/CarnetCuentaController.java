package com.taxiuap.backend.controller.cuenta;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.CarnetRequest;
import com.taxiuap.backend.identity.dto.UsuarioResponse;
import com.taxiuap.backend.identity.service.CarnetService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** "Verifica tu carnet": quien entro con Google sin CI registra su carnet con las dos fotos. */
@RestController
@RequestMapping("/api/cuenta")
@RequiredArgsConstructor
public class CarnetCuentaController {

    private final CarnetService carnetService;

    /** Multipart: "datos" (JSON), "anverso" y "reverso" (fotos JPG o PNG). */
    @PostMapping(value = "/carnet", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<UsuarioResponse>> registrar(
            @Valid @RequestPart("datos") CarnetRequest datos,
            @RequestPart("anverso") MultipartFile anverso,
            @RequestPart("reverso") MultipartFile reverso) {
        UsuarioResponse usuario = carnetService.registrar(UsuarioActual.idUsuario(), datos, anverso, reverso);
        return ResponseEntity.ok(ApiResponse.exito("Carnet registrado", usuario));
    }
}
