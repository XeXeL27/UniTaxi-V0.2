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

/**
 * "Verifica tu carnet": quien entro con Google sin CI registra su carnet con las dos fotos y la foto con
 * el carnet. Las cuentas que ya usaban la app suben aqui su foto con el carnet (o renuevan el carnet).
 */
@RestController
@RequestMapping("/api/cuenta")
@RequiredArgsConstructor
public class CarnetCuentaController {

    private final CarnetService carnetService;

    /** Multipart: "datos" (JSON), "anverso", "reverso" y "selfie" (fotos JPG o PNG). */
    @PostMapping(value = "/carnet", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<UsuarioResponse>> registrar(
            @Valid @RequestPart("datos") CarnetRequest datos,
            @RequestPart("anverso") MultipartFile anverso,
            @RequestPart("reverso") MultipartFile reverso,
            @RequestPart(value = "selfie", required = false) MultipartFile selfie) {
        UsuarioResponse usuario = carnetService.registrar(UsuarioActual.idUsuario(), datos, anverso, reverso, selfie);
        return ResponseEntity.ok(ApiResponse.exito("Carnet registrado", usuario));
    }

    /**
     * Cuenta que ya usaba la app: "selfie" (la persona con su carnet) y, si su carnet vencio o no tiene sus
     * fotos, tambien "anverso" y "reverso" del carnet. Los datos deben ser los ya registrados.
     */
    @PostMapping(value = "/carnet/actualizar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<UsuarioResponse>> actualizar(
            @RequestPart(value = "anverso", required = false) MultipartFile anverso,
            @RequestPart(value = "reverso", required = false) MultipartFile reverso,
            @RequestPart(value = "selfie", required = false) MultipartFile selfie) {
        UsuarioResponse usuario = carnetService.actualizarCuenta(UsuarioActual.idUsuario(), anverso, reverso, selfie);
        return ResponseEntity.ok(ApiResponse.exito("Foto con el carnet registrada", usuario));
    }
}
