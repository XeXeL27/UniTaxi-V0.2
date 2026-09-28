package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.entity.Administrador;
import com.taxiuap.backend.identity.repository.AdministradorRepository;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.vehicle.dto.DocumentoConductorAdminResponse;
import com.taxiuap.backend.vehicle.dto.RevisionDocumentoRequest;
import com.taxiuap.backend.vehicle.entity.DocumentoConductor;
import com.taxiuap.backend.vehicle.enums.SituacionRevision;
import com.taxiuap.backend.vehicle.service.DocumentoConductorService;

import jakarta.validation.Valid;
import com.taxiuap.backend.vehicle.dto.ActualizarDocumentoRequest;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.multipart.MultipartFile;

import lombok.RequiredArgsConstructor;

/** Revision administrativa de documentos de conductor. */
@RestController
@RequestMapping("/api/admin/documentos-conductor")
@RequiredArgsConstructor
public class DocumentoConductorAdminController {

    private final DocumentoConductorService documentoConductorService;
    private final AdministradorRepository administradorRepository;
    private final AlmacenamientoArchivos almacenamientoArchivos;

    @GetMapping
    public ResponseEntity<ApiResponse<List<DocumentoConductorAdminResponse>>> listar(
            @RequestParam(required = false) SituacionRevision situacion) {
        return ResponseEntity.ok(ApiResponse.exito(documentoConductorService.listarParaAdmin(situacion)));
    }

    /** Descarga el PDF del documento (se muestra en el navegador, Content-Disposition inline). */
    @GetMapping("/{id}/archivo")
    public ResponseEntity<Resource> archivo(@PathVariable Long id) {
        DocumentoConductor documento = documentoConductorService.obtenerActivo(id);
        Resource recurso = almacenamientoArchivos.leer(documento.getArchivoUrl());
        String nombre = documento.getTipoDocumento().name().toLowerCase() + "_conductor_"
                + documento.getConductor().getId() + ".pdf";
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline().filename(nombre).build().toString())
                .body(recurso);
    }

    /** Corrige el tipo o el vencimiento del documento. */
    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<DocumentoConductorAdminResponse>> actualizar(
            @PathVariable Long id, @Valid @RequestBody ActualizarDocumentoRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Documento actualizado", documentoConductorService.actualizarDatos(id, request)));
    }

    /** Reemplaza el PDF del documento. */
    @PutMapping(value = "/{id}/archivo", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<DocumentoConductorAdminResponse>> reemplazar(
            @PathVariable Long id, @RequestPart("archivo") MultipartFile archivo) {
        return ResponseEntity.ok(ApiResponse.exito("PDF reemplazado", documentoConductorService.reemplazarArchivoAdmin(id, archivo)));
    }

    /** Borrado logico del documento (el PDF se conserva en la carpeta de la persona). */
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long id) {
        documentoConductorService.eliminar(id);
        return ResponseEntity.ok(ApiResponse.exito("Documento eliminado", null));
    }

    @PutMapping("/{id}/revision")
    public ResponseEntity<ApiResponse<DocumentoConductorAdminResponse>> revisar(
            @PathVariable Long id, @Valid @RequestBody RevisionDocumentoRequest request) {
        Administrador adminRevisor = administradorRepository.findByUsuarioId(UsuarioActual.idUsuario())
                .orElseThrow(() -> RecursoNoEncontradoException.de("Administrador", UsuarioActual.idUsuario()));
        DocumentoConductorAdminResponse actualizado = documentoConductorService.revisar(id, request, adminRevisor);
        return ResponseEntity.ok(ApiResponse.exito("Documento revisado", actualizado));
    }
}
