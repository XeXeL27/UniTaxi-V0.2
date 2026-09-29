package com.taxiuap.backend.controller.conductor;

import java.util.List;

import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.pricing.dto.QrPagoResponse;
import com.taxiuap.backend.pricing.entity.QrPagoConductor;
import com.taxiuap.backend.pricing.service.QrPagoConductorService;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.response.ApiResponse;

import lombok.RequiredArgsConstructor;

/** QR de cobro del conductor autenticado (hasta 3). Los cambia cuando quiere, sin permiso del admin. */
@RestController
@RequestMapping("/api/conductor/qr")
@RequiredArgsConstructor
public class QrPagoConductorController {

    private final QrPagoConductorService qrService;
    private final AlmacenamientoArchivos almacenamientoArchivos;

    @GetMapping
    public ResponseEntity<ApiResponse<List<QrPagoResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(qrService.listarPropios(UsuarioActual.idUsuario())));
    }

    @GetMapping("/{id}/imagen")
    public ResponseEntity<Resource> imagen(@PathVariable Long id) {
        QrPagoConductor qr = qrService.obtenerPropio(UsuarioActual.idUsuario(), id);
        return imagenQr(almacenamientoArchivos.leer(qr.getImagenUrl()), "qr_" + id + ".png");
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<List<QrPagoResponse>>> agregar(@RequestPart("imagen") MultipartFile imagen) {
        return ResponseEntity.ok(ApiResponse.exito("QR agregado", qrService.agregar(UsuarioActual.idUsuario(), imagen)));
    }

    @PutMapping(value = "/{id}/imagen", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<List<QrPagoResponse>>> reemplazar(
            @PathVariable Long id, @RequestPart("imagen") MultipartFile imagen) {
        return ResponseEntity.ok(
                ApiResponse.exito("QR actualizado", qrService.reemplazar(UsuarioActual.idUsuario(), id, imagen)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<List<QrPagoResponse>>> eliminar(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito("QR eliminado", qrService.eliminarPropio(UsuarioActual.idUsuario(), id)));
    }

    /** Respuesta comun para las imagenes de QR (conductor, pasajero y admin). */
    public static ResponseEntity<Resource> imagenQr(Resource recurso, String nombre) {
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_PNG)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline().filename(nombre).build().toString())
                .body(recurso);
    }
}
