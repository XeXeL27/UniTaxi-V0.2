package com.taxiuap.backend.controller.cuenta;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.CompletarCorreoRequest;
import com.taxiuap.backend.identity.service.RestablecerContrasenaService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** La app pide el correo a quien entra sin tenerlo: sirve para credenciales y restablecer la contrasena. */
@RestController
@RequestMapping("/api/cuenta")
@RequiredArgsConstructor
public class CorreoCuentaController {

    private final RestablecerContrasenaService restablecerContrasenaService;

    @PostMapping("/correo")
    public ResponseEntity<ApiResponse<String>> completar(@Valid @RequestBody CompletarCorreoRequest request) {
        String correo = restablecerContrasenaService.completarCorreo(UsuarioActual.idUsuario(), request);
        return ResponseEntity.ok(ApiResponse.exito("Correo guardado", correo));
    }
}
