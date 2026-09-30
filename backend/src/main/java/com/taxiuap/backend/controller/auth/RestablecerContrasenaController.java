package com.taxiuap.backend.controller.auth;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.identity.dto.OlvidoContrasenaRequest;
import com.taxiuap.backend.identity.dto.RestablecerContrasenaRequest;
import com.taxiuap.backend.identity.service.RestablecerContrasenaService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** "Olvide mi contrasena": codigo por correo y contrasena nueva (publico, sin sesion). */
@RestController
@RequestMapping("/api/auth/contrasena")
@RequiredArgsConstructor
public class RestablecerContrasenaController {

    private final RestablecerContrasenaService restablecerContrasenaService;

    @PostMapping("/olvido")
    public ResponseEntity<ApiResponse<Void>> olvido(@Valid @RequestBody OlvidoContrasenaRequest request) {
        restablecerContrasenaService.enviarCodigo(request.correo());
        return ResponseEntity.ok(ApiResponse.exito(
                "Si el correo esta registrado, te llegara un codigo en unos minutos", null));
    }

    @PostMapping("/restablecer")
    public ResponseEntity<ApiResponse<Void>> restablecer(@Valid @RequestBody RestablecerContrasenaRequest request) {
        restablecerContrasenaService.restablecer(request);
        return ResponseEntity.ok(ApiResponse.exito("Contrasena restablecida. Ya puedes ingresar", null));
    }
}
