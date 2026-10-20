package com.taxiuap.backend.controller.cuenta;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.CambiarContrasenaConCodigoRequest;
import com.taxiuap.backend.identity.dto.CambiarContrasenaRequest;
import com.taxiuap.backend.identity.dto.CodigoContrasenaResponse;
import com.taxiuap.backend.identity.dto.VerificarCodigoContrasenaRequest;
import com.taxiuap.backend.identity.dto.VerificarContrasenaActualRequest;
import com.taxiuap.backend.identity.service.CambioContrasenaService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Cambio de contrasena de la cuenta con la que se inicio sesion (pasajero, conductor o admin): con la
 * contrasena actual o, si no la recuerda, con un codigo enviado a su correo registrado. Al terminar llega un
 * correo de aviso (sin la contrasena).
 */
@RestController
@RequestMapping("/api/cuenta/contrasena")
@RequiredArgsConstructor
public class ContrasenaController {

    private final CambioContrasenaService cambioContrasenaService;

    /** Con la contrasena actual, la nueva y su confirmacion (tambien lo usan las apps anteriores y el panel). */
    @PostMapping
    public ResponseEntity<ApiResponse<Void>> cambiar(@Valid @RequestBody CambiarContrasenaRequest request) {
        cambioContrasenaService.cambiarConActual(UsuarioActual.idUsuario(), request);
        return ResponseEntity.ok(ApiResponse.exito("Contrasena actualizada", null));
    }

    /** Paso 2 con la contrasena actual: solo la revisa. */
    @PostMapping("/verificar")
    public ResponseEntity<ApiResponse<Void>> verificar(@Valid @RequestBody VerificarContrasenaActualRequest request) {
        cambioContrasenaService.verificarActual(UsuarioActual.idUsuario(), request.actual());
        return ResponseEntity.ok(ApiResponse.exito("Contrasena verificada", null));
    }

    /** A que correo llegaria el codigo (oculto en parte). */
    @GetMapping("/correo")
    public ResponseEntity<ApiResponse<CodigoContrasenaResponse>> correo() {
        return ResponseEntity.ok(ApiResponse.exito(cambioContrasenaService.correo(UsuarioActual.idUsuario())));
    }

    /** Envia el codigo al correo registrado. */
    @PostMapping("/codigo")
    public ResponseEntity<ApiResponse<CodigoContrasenaResponse>> enviarCodigo() {
        return ResponseEntity.ok(ApiResponse.exito("Codigo enviado",
                cambioContrasenaService.enviarCodigo(UsuarioActual.idUsuario())));
    }

    /** Paso 2 con el codigo: lo revisa sin gastarlo. */
    @PostMapping("/codigo/verificar")
    public ResponseEntity<ApiResponse<Void>> verificarCodigo(@Valid @RequestBody VerificarCodigoContrasenaRequest request) {
        cambioContrasenaService.verificarCodigo(UsuarioActual.idUsuario(), request.codigo());
        return ResponseEntity.ok(ApiResponse.exito("Codigo verificado", null));
    }

    /** Con el codigo, la nueva y su confirmacion. */
    @PostMapping("/con-codigo")
    public ResponseEntity<ApiResponse<Void>> cambiarConCodigo(@Valid @RequestBody CambiarContrasenaConCodigoRequest request) {
        cambioContrasenaService.cambiarConCodigo(UsuarioActual.idUsuario(), request);
        return ResponseEntity.ok(ApiResponse.exito("Contrasena actualizada", null));
    }
}
