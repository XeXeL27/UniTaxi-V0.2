package com.taxiuap.backend.controller.conductor;

import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.CarnetRequest;
import com.taxiuap.backend.identity.dto.LicenciaRequest;
import com.taxiuap.backend.identity.dto.PerfilConductorResponse;
import com.taxiuap.backend.identity.service.CarnetService;
import com.taxiuap.backend.identity.service.LicenciaService;
import com.taxiuap.backend.identity.service.PerfilConductorService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Fotos del carnet y de la licencia del conductor (Mis documentos). Las ve siempre; las cambia solo
 * con un permiso del administrador (CARNET o LICENCIA) y confirmando con su contrasena.
 */
@RestController
@RequestMapping("/api/conductor")
@RequiredArgsConstructor
public class CarnetLicenciaConductorController {

    private final CarnetService carnetService;
    private final LicenciaService licenciaService;
    private final PerfilConductorService perfilConductorService;

    @GetMapping("/carnet/{lado}")
    public ResponseEntity<Resource> carnet(@PathVariable String lado) {
        return imagen(carnetService.leer(UsuarioActual.idUsuario(), lado));
    }

    @GetMapping("/licencia/{lado}")
    public ResponseEntity<Resource> licencia(@PathVariable String lado) {
        return imagen(licenciaService.leerPorUsuario(UsuarioActual.idUsuario(), lado));
    }

    /** Multipart: "datos" (CI, complemento, fecha y contrasena), "anverso" y "reverso". */
    @PutMapping(value = "/carnet", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<PerfilConductorResponse>> cambiarCarnet(
            @Valid @RequestPart("datos") CarnetRequest datos,
            @RequestPart("anverso") MultipartFile anverso,
            @RequestPart("reverso") MultipartFile reverso) {
        carnetService.reemplazarPorConductor(UsuarioActual.idUsuario(), datos, anverso, reverso);
        return ResponseEntity.ok(ApiResponse.exito("Carnet actualizado", perfilConductorService.obtener(UsuarioActual.idUsuario())));
    }

    /** Multipart: "datos" (numero, categoria, vencimiento y contrasena), "anverso" y "reverso". */
    @PutMapping(value = "/licencia", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<PerfilConductorResponse>> cambiarLicencia(
            @Valid @RequestPart("datos") LicenciaRequest datos,
            @RequestPart("anverso") MultipartFile anverso,
            @RequestPart("reverso") MultipartFile reverso) {
        licenciaService.reemplazarPorConductor(UsuarioActual.idUsuario(), datos, anverso, reverso);
        return ResponseEntity.ok(ApiResponse.exito("Licencia actualizada", perfilConductorService.obtener(UsuarioActual.idUsuario())));
    }

    private static ResponseEntity<Resource> imagen(Resource recurso) {
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_JPEG)
                .cacheControl(CacheControl.noCache())
                .body(recurso);
    }
}
