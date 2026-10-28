package com.taxiuap.backend.controller.pasajero;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.location.dto.LatidoPasajeroRequest;
import com.taxiuap.backend.location.service.PresenciaPasajeroService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Posicion del pasajero mientras tiene la app abierta en pantalla (mapa Usuarios en linea del
 * panel). No se guarda en la base de datos.
 */
@RestController
@RequestMapping("/api/pasajero/latido")
@RequiredArgsConstructor
public class LatidoPasajeroController {

    private final PresenciaPasajeroService presenciaPasajeroService;

    @PostMapping
    public ResponseEntity<ApiResponse<Void>> latido(@Valid @RequestBody LatidoPasajeroRequest request) {
        presenciaPasajeroService.registrar(UsuarioActual.idUsuario(), request);
        return ResponseEntity.ok(ApiResponse.exito(null));
    }

    /** La app paso a segundo plano o cerro sesion. */
    @PostMapping("/salir")
    public ResponseEntity<ApiResponse<Void>> salir() {
        presenciaPasajeroService.salir(UsuarioActual.idUsuario());
        return ResponseEntity.ok(ApiResponse.exito(null));
    }
}
