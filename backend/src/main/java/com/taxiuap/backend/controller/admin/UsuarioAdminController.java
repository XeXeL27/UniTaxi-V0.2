package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.UsuarioAdminResponse;
import com.taxiuap.backend.identity.service.GestionUsuarioService;
import com.taxiuap.backend.shared.response.ApiResponse;

import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import com.taxiuap.backend.identity.service.CarnetService;
import com.taxiuap.backend.identity.service.FotoPerfilService;
import com.taxiuap.backend.identity.service.EdicionUsuarioAdminService;
import com.taxiuap.backend.identity.dto.EdicionUsuarioAdminRequest;
import com.taxiuap.backend.identity.dto.UsuarioDetalleAdminResponse;
import org.springframework.web.bind.annotation.PostMapping;

import com.taxiuap.backend.identity.dto.CambiarEstadoUsuarioRequest;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Cuentas de usuario desde el panel admin. El alta se hace por /api/admin/personas/{id}/usuarios. */
@RestController
@RequestMapping("/api/admin/usuarios")
@RequiredArgsConstructor
public class UsuarioAdminController {

    private final GestionUsuarioService gestionUsuarioService;
    private final FotoPerfilService fotoPerfilService;
    private final CarnetService carnetService;
    private final EdicionUsuarioAdminService edicionUsuarioAdminService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<UsuarioAdminResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(gestionUsuarioService.listar()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long id) {
        gestionUsuarioService.eliminar(id, UsuarioActual.idUsuario());
        return ResponseEntity.ok(ApiResponse.exito("Usuario eliminado", null));
    }

    /** Suspende (S) o habilita (A) la cuenta; la suspendida sale de la app en su siguiente peticion. */
    @PutMapping("/{id}/estado")
    public ResponseEntity<ApiResponse<UsuarioAdminResponse>> cambiarEstado(
            @PathVariable Long id, @Valid @RequestBody CambiarEstadoUsuarioRequest request) {
        UsuarioAdminResponse usuario = gestionUsuarioService.cambiarEstado(id, request.estado(), UsuarioActual.idUsuario());
        return ResponseEntity.ok(ApiResponse.exito(
                request.estado() == EstadoRegistro.S ? "Cuenta suspendida" : "Cuenta habilitada", usuario));
    }

    /** Foto de perfil de una cuenta (404 si no tiene). */
    @GetMapping("/{id}/foto")
    public ResponseEntity<Resource> foto(@PathVariable Long id) {
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_JPEG)
                .cacheControl(CacheControl.noCache())
                .body(fotoPerfilService.leer(id));
    }

    /** Foto del carnet de la persona de la cuenta: lado "anverso" o "reverso" (404 si no la tiene). */
    @GetMapping("/{id}/carnet/{lado}")
    public ResponseEntity<Resource> carnet(@PathVariable Long id, @PathVariable String lado) {
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_JPEG)
                .cacheControl(CacheControl.noCache())
                .body(carnetService.leer(id, lado));
    }

    /** Cambia una o las dos fotos del carnet de la persona de la cuenta (multipart "anverso" / "reverso"). */
    @PutMapping(value = "/{id}/carnet", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<Void>> cambiarCarnet(
            @PathVariable Long id,
            @RequestPart(value = "anverso", required = false) MultipartFile anverso,
            @RequestPart(value = "reverso", required = false) MultipartFile reverso) {
        carnetService.reemplazarPorAdmin(id, anverso, reverso);
        return ResponseEntity.ok(ApiResponse.exito("Fotos del carnet actualizadas", null));
    }

    /** Todos los datos de la cuenta y de la persona para el modal Editar (incluida la licencia del conductor). */
    @GetMapping("/{id}/detalle")
    public ResponseEntity<ApiResponse<UsuarioDetalleAdminResponse>> detalle(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(edicionUsuarioAdminService.detalle(id)));
    }

    /**
     * Edita todo junto. Multipart: "datos" (JSON) y, opcionales, "carnetAnverso", "carnetReverso",
     * "licenciaAnverso" y "licenciaReverso".
     */
    @PutMapping(value = "/{id}/datos", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<UsuarioDetalleAdminResponse>> actualizar(
            @PathVariable Long id,
            @Valid @RequestPart("datos") EdicionUsuarioAdminRequest datos,
            @RequestPart(value = "carnetAnverso", required = false) MultipartFile carnetAnverso,
            @RequestPart(value = "carnetReverso", required = false) MultipartFile carnetReverso,
            @RequestPart(value = "licenciaAnverso", required = false) MultipartFile licenciaAnverso,
            @RequestPart(value = "licenciaReverso", required = false) MultipartFile licenciaReverso) {
        return ResponseEntity.ok(ApiResponse.exito("Usuario actualizado", edicionUsuarioAdminService.actualizar(
                id, datos, carnetAnverso, carnetReverso, licenciaAnverso, licenciaReverso)));
    }

    /** Genera una contrasena nueva y la envia con el usuario al correo actual de la persona. */
    @PostMapping("/{id}/credenciales")
    public ResponseEntity<ApiResponse<Void>> reenviarCredenciales(@PathVariable Long id) {
        edicionUsuarioAdminService.reenviarCredenciales(id);
        return ResponseEntity.ok(ApiResponse.exito("Credenciales enviadas al correo", null));
    }
}
