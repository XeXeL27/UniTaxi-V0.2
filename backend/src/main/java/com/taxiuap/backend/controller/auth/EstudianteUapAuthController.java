package com.taxiuap.backend.controller.auth;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.dto.RegistroEstudianteUapRequest;
import com.taxiuap.backend.identity.dto.RegistroEstudianteUapResponse;
import com.taxiuap.backend.identity.dto.TokenResponse;
import com.taxiuap.backend.identity.service.RegistroEstudianteUapService;
import com.taxiuap.backend.institution.dto.RuRequest;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Registro publico como estudiante de la UAP: RU (consultado en el SIGSE) y fotos del carnet. */
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class EstudianteUapAuthController {

    private final RegistroEstudianteUapService registroEstudianteUapService;

    /** Paso 1: el RU. Limite de consultas por IP. */
    @PostMapping("/estudiante-uap/consulta")
    public ResponseEntity<ApiResponse<RegistroEstudianteUapResponse>> consultar(@Valid @RequestBody RuRequest request,
            HttpServletRequest peticion) {
        return ResponseEntity.ok(ApiResponse.exito(
                registroEstudianteUapService.consultar(request.ru(), peticion.getRemoteAddr())));
    }

    /** Paso 2: "datos" (codigo + carnet confirmado) y las fotos "anverso" y "reverso". */
    @PostMapping(value = "/registro/estudiante-uap", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<TokenResponse>> registrar(
            @Valid @RequestPart("datos") RegistroEstudianteUapRequest datos,
            @RequestPart("anverso") MultipartFile anverso,
            @RequestPart("reverso") MultipartFile reverso) {
        TokenResponse tokens = registroEstudianteUapService.registrar(datos, anverso, reverso);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.exito("Registro completado", tokens));
    }
}
