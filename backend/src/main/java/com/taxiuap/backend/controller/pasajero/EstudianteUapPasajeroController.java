package com.taxiuap.backend.controller.pasajero;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.service.RegistroEstudianteUapService;
import com.taxiuap.backend.institution.dto.EstadoEstudianteResponse;
import com.taxiuap.backend.institution.dto.RuRequest;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Perfil > "Soy estudiante UAP": situacion de estudiante del pasajero y verificacion con su RU. */
@RestController
@RequestMapping("/api/pasajero/estudiante-uap")
@RequiredArgsConstructor
public class EstudianteUapPasajeroController {

    private final RegistroEstudianteUapService registroEstudianteUapService;

    /** Si su matricula vencio se vuelve a consultar el SIGSE en ese momento. */
    @GetMapping
    public ResponseEntity<ApiResponse<EstadoEstudianteResponse>> estado() {
        return ResponseEntity.ok(ApiResponse.exito(registroEstudianteUapService.estadoCuenta(UsuarioActual.idUsuario())));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<EstadoEstudianteResponse>> verificar(@Valid @RequestBody RuRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Quedaste registrado como estudiante UAP",
                registroEstudianteUapService.verificarCuenta(UsuarioActual.idUsuario(), request.ru())));
    }
}
