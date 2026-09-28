package com.taxiuap.backend.controller.conductor;

import java.util.List;

import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.vehicle.entity.DocumentoConductor;
import com.taxiuap.backend.vehicle.dto.DocumentoConductorResponse;
import com.taxiuap.backend.vehicle.service.DocumentoConductorService;

import lombok.RequiredArgsConstructor;

/** Documentos del conductor autenticado. */
@RestController
@RequestMapping("/api/conductor/documentos")
@RequiredArgsConstructor
public class DocumentoConductorController {

    private final DocumentoConductorService documentoConductorService;
    private final AlmacenamientoArchivos almacenamientoArchivos;

    @GetMapping
    public ResponseEntity<ApiResponse<List<DocumentoConductorResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(documentoConductorService.listar(UsuarioActual.idUsuario())));
    }

    /** PDF del documento, para verlo dentro de la app. */
    @GetMapping("/{id}/archivo")
    public ResponseEntity<Resource> archivo(@PathVariable Long id) {
        DocumentoConductor documento = documentoConductorService.obtenerDelConductor(UsuarioActual.idUsuario(), id);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline()
                        .filename(documento.getTipoDocumento().name().toLowerCase() + ".pdf").build().toString())
                .body(almacenamientoArchivos.leer(documento.getArchivoUrl()));
    }

    /** Reemplaza el PDF (solo con permiso vigente del administrador para ese documento). */
    @PutMapping(value = "/{id}/archivo", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<DocumentoConductorResponse>> reemplazar(
            @PathVariable Long id, @RequestPart("archivo") MultipartFile archivo) {
        DocumentoConductorResponse actualizado =
                documentoConductorService.reemplazarArchivo(UsuarioActual.idUsuario(), id, archivo);
        return ResponseEntity.ok(ApiResponse.exito("Documento enviado a revision", actualizado));
    }
}
