package com.taxiuap.backend.controller.auth;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.dto.LecturaDocumentoResponse;
import com.taxiuap.backend.identity.dto.LecturaSelfieResponse;
import com.taxiuap.backend.identity.enums.DocumentoIdentidad;
import com.taxiuap.backend.identity.enums.LadoDocumento;
import com.taxiuap.backend.identity.service.LecturaDocumentoService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;

/**
 * Lectura con Gemini de una foto del carnet o de la licencia. Es publica porque el registro con el
 * formulario todavia no tiene sesion; cada IP tiene un limite de lecturas por hora.
 */
@RestController
@RequestMapping("/api/auth/documentos")
@RequiredArgsConstructor
public class LecturaDocumentoController {

    private final LecturaDocumentoService lecturaDocumentoService;

    /** Multipart: "foto" (JPG o PNG), documento (CARNET o LICENCIA) y lado (ANVERSO o REVERSO). */
    @PostMapping(value = "/leer", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<LecturaDocumentoResponse>> leer(
            @RequestPart("foto") MultipartFile foto,
            @RequestParam DocumentoIdentidad documento,
            @RequestParam LadoDocumento lado,
            HttpServletRequest peticion) {
        LecturaDocumentoResponse lectura = lecturaDocumentoService.leer(foto, documento, lado, peticion.getRemoteAddr());
        return ResponseEntity.ok(ApiResponse.exito(lectura));
    }

    /**
     * Revisa la foto de la persona sosteniendo su carnet. Multipart: "foto" y, opcional, "anverso" (la foto
     * del anverso que ya tomo: ayuda a comparar la cara y su numero debe ser el mismo).
     */
    @PostMapping(value = "/selfie", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<LecturaSelfieResponse>> selfie(
            @RequestPart("foto") MultipartFile foto,
            @RequestPart(value = "anverso", required = false) MultipartFile anverso,
            HttpServletRequest peticion) {
        return ResponseEntity.ok(ApiResponse.exito(lecturaDocumentoService.leerSelfie(foto, anverso,
                peticion.getRemoteAddr())));
    }
}
