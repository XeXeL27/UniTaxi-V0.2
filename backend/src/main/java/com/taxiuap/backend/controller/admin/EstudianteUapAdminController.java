package com.taxiuap.backend.controller.admin;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.identity.service.RegistroEstudianteUapService;
import com.taxiuap.backend.institution.dto.DatosSigseAdminResponse;
import com.taxiuap.backend.institution.dto.EstadoEstudianteResponse;
import com.taxiuap.backend.institution.dto.RuRequest;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Estudiantes UAP en el panel: lo que dice el SIGSE de un RU y "Verificar con SIGSE" de un pasajero. */
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class EstudianteUapAdminController {

    private final RegistroEstudianteUapService registroEstudianteUapService;

    @GetMapping("/estudiantes-uap/{ru}")
    public ResponseEntity<ApiResponse<DatosSigseAdminResponse>> sigse(@PathVariable String ru) {
        return ResponseEntity.ok(ApiResponse.exito(registroEstudianteUapService.sigseParaAdmin(ru)));
    }

    @PostMapping("/pasajeros/{idPasajero}/estudiante-uap")
    public ResponseEntity<ApiResponse<EstadoEstudianteResponse>> verificar(@PathVariable Long idPasajero,
            @Valid @RequestBody RuRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Pasajero verificado como estudiante UAP",
                registroEstudianteUapService.verificarPorAdmin(idPasajero, request.ru())));
    }
}
