package com.taxiuap.backend.controller.auth;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.identity.dto.CambiarContrasenaRecuperacionRequest;
import com.taxiuap.backend.identity.dto.CarnetRegistradoRequest;
import com.taxiuap.backend.identity.dto.CodigoRecuperacionResponse;
import com.taxiuap.backend.identity.dto.CuentaRegistradaResponse;
import com.taxiuap.backend.identity.dto.MensajeAyudaIngresoRequest;
import com.taxiuap.backend.identity.dto.RecuperacionRequest;
import com.taxiuap.backend.identity.dto.RecuperacionTerminadaResponse;
import com.taxiuap.backend.identity.dto.VerificarCodigoRecuperacionRequest;
import com.taxiuap.backend.identity.service.RecuperarCuentaService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * "Recuperar mis credenciales" desde el registro (publico, sin sesion): si el carnet ya esta registrado,
 * codigos al correo registrado, contrasena nueva o mensaje al administrador.
 */
@RestController
@RequestMapping("/api/auth/recuperar")
@RequiredArgsConstructor
public class RecuperarCuentaController {

    private final RecuperarCuentaService recuperarCuentaService;

    @PostMapping("/por-carnet")
    public ResponseEntity<ApiResponse<CuentaRegistradaResponse>> porCarnet(
            @Valid @RequestBody CarnetRegistradoRequest request, HttpServletRequest peticion) {
        return ResponseEntity.ok(ApiResponse.exito(recuperarCuentaService.porCarnet(request, peticion.getRemoteAddr())));
    }

    @PostMapping("/codigo")
    public ResponseEntity<ApiResponse<CodigoRecuperacionResponse>> codigo(@Valid @RequestBody RecuperacionRequest request) {
        CodigoRecuperacionResponse respuesta = recuperarCuentaService.enviarCodigo(request.recuperacion());
        return ResponseEntity.ok(ApiResponse.exito("Te enviamos un código a " + respuesta.correo(), respuesta));
    }

    @PostMapping("/verificar")
    public ResponseEntity<ApiResponse<Void>> verificar(@Valid @RequestBody VerificarCodigoRecuperacionRequest request) {
        recuperarCuentaService.verificarCodigo(request);
        return ResponseEntity.ok(ApiResponse.exito("Código correcto", null));
    }

    @PostMapping("/contrasena")
    public ResponseEntity<ApiResponse<RecuperacionTerminadaResponse>> contrasena(
            @Valid @RequestBody CambiarContrasenaRecuperacionRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Contraseña actualizada. Ya puedes ingresar",
                recuperarCuentaService.cambiarContrasena(request)));
    }

    @PostMapping("/mensaje")
    public ResponseEntity<ApiResponse<Void>> mensaje(@Valid @RequestBody MensajeAyudaIngresoRequest request,
            HttpServletRequest peticion) {
        recuperarCuentaService.enviarMensaje(request, peticion.getRemoteAddr());
        return ResponseEntity.ok(ApiResponse.exito("Tu mensaje llegó al administrador", null));
    }
}
