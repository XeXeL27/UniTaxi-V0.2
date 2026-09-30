package com.taxiuap.backend.controller.cuenta;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.ActualizarDatosCuentaRequest;
import com.taxiuap.backend.identity.dto.UsuarioResponse;
import com.taxiuap.backend.identity.service.DatosCuentaService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Mi perfil de la app: cambio de datos personales confirmado con la contrasena. */
@RestController
@RequestMapping("/api/cuenta")
@RequiredArgsConstructor
public class DatosCuentaController {

    private final DatosCuentaService datosCuentaService;

    @PutMapping("/datos")
    public ResponseEntity<ApiResponse<UsuarioResponse>> actualizar(@Valid @RequestBody ActualizarDatosCuentaRequest request) {
        UsuarioResponse usuario = datosCuentaService.actualizar(UsuarioActual.idUsuario(), request);
        return ResponseEntity.ok(ApiResponse.exito("Datos actualizados", usuario));
    }

    /** Guia de inicio terminada o saltada. */
    @PostMapping("/guia-vista")
    public ResponseEntity<ApiResponse<Void>> guiaVista() {
        datosCuentaService.marcarGuiaVista(UsuarioActual.idUsuario());
        return ResponseEntity.ok(ApiResponse.exito("Guia marcada como vista", null));
    }
}
