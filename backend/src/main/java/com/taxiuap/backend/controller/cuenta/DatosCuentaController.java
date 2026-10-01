package com.taxiuap.backend.controller.cuenta;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
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

/**
 * Mi perfil de la app: cambio de correo y telefono (y licencia en blanco del conductor) confirmado
 * con la contrasena, aviso de credenciales y guia de inicio.
 */
@RestController
@RequestMapping("/api/cuenta")
@RequiredArgsConstructor
public class DatosCuentaController {

    private final DatosCuentaService datosCuentaService;

    /** Datos de la cuenta actual (por ejemplo, para saber si el administrador ya aprobo su carnet). */
    @GetMapping("/yo")
    public ResponseEntity<ApiResponse<UsuarioResponse>> actual() {
        return ResponseEntity.ok(ApiResponse.exito(datosCuentaService.actual(UsuarioActual.idUsuario())));
    }

    /** Cambia correo y telefono (y la licencia en blanco del conductor), confirmado con la contrasena. */
    @PutMapping("/datos")
    public ResponseEntity<ApiResponse<UsuarioResponse>> actualizar(@Valid @RequestBody ActualizarDatosCuentaRequest request) {
        UsuarioResponse usuario = datosCuentaService.actualizar(UsuarioActual.idUsuario(), request);
        return ResponseEntity.ok(ApiResponse.exito("Datos actualizados", usuario));
    }

    /** La persona ya vio el aviso "Tus credenciales llegaron a tu correo". */
    @PostMapping("/aviso-credenciales")
    public ResponseEntity<ApiResponse<Void>> avisoCredencialesVisto() {
        datosCuentaService.marcarAvisoCredencialesVisto(UsuarioActual.idUsuario());
        return ResponseEntity.ok(ApiResponse.exito("Aviso marcado como visto", null));
    }

    /** Guia de inicio terminada o saltada. */
    @PostMapping("/guia-vista")
    public ResponseEntity<ApiResponse<Void>> guiaVista() {
        datosCuentaService.marcarGuiaVista(UsuarioActual.idUsuario());
        return ResponseEntity.ok(ApiResponse.exito("Guia marcada como vista", null));
    }
}
