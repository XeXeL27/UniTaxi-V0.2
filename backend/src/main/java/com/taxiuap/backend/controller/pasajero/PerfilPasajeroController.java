package com.taxiuap.backend.controller.pasajero;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.ActualizarPerfilRequest;
import com.taxiuap.backend.identity.dto.PerfilPasajeroResponse;
import com.taxiuap.backend.identity.service.PerfilPasajeroService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.multipart.MultipartFile;
import com.taxiuap.backend.identity.service.FotoPerfilService;

import lombok.RequiredArgsConstructor;

/** Perfil del pasajero autenticado. */
@RestController
@RequestMapping("/api/pasajero/perfil")
@RequiredArgsConstructor
public class PerfilPasajeroController {

    private final PerfilPasajeroService perfilPasajeroService;
    private final FotoPerfilService fotoPerfilService;

    @GetMapping
    public ResponseEntity<ApiResponse<PerfilPasajeroResponse>> obtener() {
        return ResponseEntity.ok(ApiResponse.exito(perfilPasajeroService.obtener(UsuarioActual.idUsuario())));
    }

    @PutMapping
    public ResponseEntity<ApiResponse<PerfilPasajeroResponse>> actualizar(
            @Valid @RequestBody ActualizarPerfilRequest request) {
        PerfilPasajeroResponse actualizado = perfilPasajeroService.actualizar(UsuarioActual.idUsuario(), request);
        return ResponseEntity.ok(ApiResponse.exito("Perfil actualizado", actualizado));
    }

    /** Sube o cambia la foto de perfil; el servidor la recorta cuadrada para el circulo. */
    @PostMapping(value = "/foto", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<String>> subirFoto(@RequestPart("foto") MultipartFile foto) {
        return ResponseEntity.ok(ApiResponse.exito("Foto actualizada", fotoPerfilService.subir(UsuarioActual.idUsuario(), foto)));
    }

    @GetMapping("/foto")
    public ResponseEntity<Resource> foto() {
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_JPEG)
                .cacheControl(CacheControl.noCache())
                .body(fotoPerfilService.leer(UsuarioActual.idUsuario()));
    }
}
