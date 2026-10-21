package com.taxiuap.backend.controller.auth;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.communication.dto.AyudaIngresoLoginRequest;
import com.taxiuap.backend.communication.service.AyudaIngresoService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Mensaje al administrador desde el login (publico, sin sesion): cuenta suspendida u otro problema. */
@RestController
@RequestMapping("/api/auth/ayuda-ingreso")
@RequiredArgsConstructor
public class AyudaIngresoController {

    private final AyudaIngresoService ayudaIngresoService;

    @PostMapping
    public ResponseEntity<ApiResponse<Void>> enviar(@Valid @RequestBody AyudaIngresoLoginRequest request,
            HttpServletRequest peticion) {
        ayudaIngresoService.desdeLogin(request, peticion.getRemoteAddr());
        return ResponseEntity.ok(ApiResponse.exito("Tu mensaje llegó al administrador", null));
    }
}
