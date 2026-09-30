package com.taxiuap.backend.controller.cuenta;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.ActualizarDatosCuentaRequest;
import com.taxiuap.backend.identity.dto.ConfirmarDatosCuentaRequest;
import com.taxiuap.backend.identity.dto.UsuarioResponse;
import com.taxiuap.backend.identity.service.DatosCuentaService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Mi perfil de la app: cambio de correo y telefono (y licencia en blanco del conductor) en dos
 * pasos, con un codigo enviado al correo actual.
 */
@RestController
@RequestMapping("/api/cuenta")
@RequiredArgsConstructor
public class DatosCuentaController {

    private final DatosCuentaService datosCuentaService;

    @PostMapping("/datos/codigo")
    public ResponseEntity<ApiResponse<String>> pedirCodigo(@Valid @RequestBody ActualizarDatosCuentaRequest request) {
        String correo = datosCuentaService.solicitarCambio(UsuarioActual.idUsuario(), request);
        return ResponseEntity.ok(ApiResponse.exito("Codigo enviado a " + correo, correo));
    }

    @PutMapping("/datos")
    public ResponseEntity<ApiResponse<UsuarioResponse>> confirmar(@Valid @RequestBody ConfirmarDatosCuentaRequest request) {
        UsuarioResponse usuario = datosCuentaService.confirmarCambio(UsuarioActual.idUsuario(), request);
        return ResponseEntity.ok(ApiResponse.exito("Datos actualizados", usuario));
    }

    /** Guia de inicio terminada o saltada. */
    @PostMapping("/guia-vista")
    public ResponseEntity<ApiResponse<Void>> guiaVista() {
        datosCuentaService.marcarGuiaVista(UsuarioActual.idUsuario());
        return ResponseEntity.ok(ApiResponse.exito("Guia marcada como vista", null));
    }
}
