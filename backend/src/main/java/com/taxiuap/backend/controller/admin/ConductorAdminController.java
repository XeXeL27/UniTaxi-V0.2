package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.dto.LicenciaRequest;
import com.taxiuap.backend.identity.service.LicenciaService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.controller.conductor.QrPagoConductorController;
import com.taxiuap.backend.identity.dto.CambiarSituacionConductorRequest;
import com.taxiuap.backend.pricing.dto.QrPagoResponse;
import com.taxiuap.backend.pricing.service.QrPagoConductorService;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.identity.dto.ConductorAdminResponse;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.service.GestionConductorService;
import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.vehicle.dto.DocumentoConductorAdminResponse;
import com.taxiuap.backend.vehicle.service.DocumentoConductorService;

import jakarta.validation.Valid;
import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.OtorgarPermisoRequest;
import com.taxiuap.backend.identity.dto.PerfilConductorResponse;
import com.taxiuap.backend.identity.dto.PermisoEdicionResponse;
import com.taxiuap.backend.identity.entity.Administrador;
import com.taxiuap.backend.identity.repository.AdministradorRepository;
import com.taxiuap.backend.identity.service.PerfilConductorService;
import com.taxiuap.backend.identity.service.PermisoEdicionService;
import com.taxiuap.backend.rating.dto.CalificacionesRecibidasResponse;
import com.taxiuap.backend.rating.service.CalificacionService;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.service.ViajeService;
import com.taxiuap.backend.vehicle.dto.VehiculoResponse;
import com.taxiuap.backend.vehicle.service.VehiculoService;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;

import lombok.RequiredArgsConstructor;

/** Revision administrativa de conductores. */
@RestController
@RequestMapping("/api/admin/conductores")
@RequiredArgsConstructor
public class ConductorAdminController {

    private final GestionConductorService gestionConductorService;
    private final DocumentoConductorService documentoConductorService;
    private final PerfilConductorService perfilConductorService;
    private final VehiculoService vehiculoService;
    private final ViajeService viajeService;
    private final CalificacionService calificacionService;
    private final PermisoEdicionService permisoEdicionService;
    private final AdministradorRepository administradorRepository;
    private final QrPagoConductorService qrPagoConductorService;
    private final AlmacenamientoArchivos almacenamientoArchivos;
    private final LicenciaService licenciaService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<ConductorAdminResponse>>> listar(
            @RequestParam(required = false) SituacionAprobacion situacion) {
        return ResponseEntity.ok(ApiResponse.exito(gestionConductorService.listar(situacion)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<ConductorAdminResponse>> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(gestionConductorService.obtener(id)));
    }

    @GetMapping("/{id}/documentos")
    public ResponseEntity<ApiResponse<List<DocumentoConductorAdminResponse>>> documentos(@PathVariable Long id) {
        gestionConductorService.obtener(id);
        return ResponseEntity.ok(ApiResponse.exito(documentoConductorService.listarDeConductor(id)));
    }

    /** Todo lo que ve el conductor en su perfil (datos, licencia, foto, billetera). */
    @GetMapping("/{id}/perfil")
    public ResponseEntity<ApiResponse<PerfilConductorResponse>> perfil(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(perfilConductorService.obtenerPorConductor(id)));
    }

    @GetMapping("/{id}/vehiculos")
    public ResponseEntity<ApiResponse<List<VehiculoResponse>>> vehiculos(@PathVariable Long id) {
        Long idUsuario = perfilConductorService.obtenerPorConductor(id).idUsuario();
        return ResponseEntity.ok(ApiResponse.exito(vehiculoService.listar(idUsuario)));
    }

    @GetMapping("/{id}/viajes")
    public ResponseEntity<ApiResponse<List<ViajeResponse>>> viajes(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.listarPorConductor(id)));
    }

    @GetMapping("/{id}/calificaciones")
    public ResponseEntity<ApiResponse<CalificacionesRecibidasResponse>> calificaciones(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(calificacionService.recibidasPorConductor(id)));
    }

    /** Permisos de edicion vigentes del conductor. */
    @GetMapping("/{id}/permisos")
    public ResponseEntity<ApiResponse<List<PermisoEdicionResponse>>> permisos(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(permisoEdicionService.vigentes(id)));
    }

    /** Habilita al conductor a actualizar sus datos y/o documentos puntuales (vence en una hora). */
    @PostMapping("/{id}/permisos")
    public ResponseEntity<ApiResponse<List<PermisoEdicionResponse>>> otorgarPermisos(
            @PathVariable Long id, @Valid @RequestBody OtorgarPermisoRequest request) {
        Administrador admin = administradorRepository.findByUsuarioId(UsuarioActual.idUsuario())
                .orElseThrow(() -> RecursoNoEncontradoException.de("Administrador", UsuarioActual.idUsuario()));
        return ResponseEntity.ok(ApiResponse.exito("Permiso otorgado", permisoEdicionService.otorgar(id, request, admin)));
    }

    @DeleteMapping("/{id}/permisos")
    public ResponseEntity<ApiResponse<Void>> revocarPermisos(@PathVariable Long id) {
        permisoEdicionService.revocar(id);
        return ResponseEntity.ok(ApiResponse.exito("Permisos quitados", null));
    }

    @PutMapping("/{id}/situacion")
    public ResponseEntity<ApiResponse<ConductorAdminResponse>> cambiarSituacion(
            @PathVariable Long id, @Valid @RequestBody CambiarSituacionConductorRequest request) {
        ConductorAdminResponse actualizado = gestionConductorService.cambiarSituacion(id, request);
        return ResponseEntity.ok(ApiResponse.exito("Situacion del conductor actualizada", actualizado));
    }

    /** Foto de la licencia del conductor: lado "anverso" o "reverso" (404 si no la tiene). */
    @GetMapping("/{id}/licencia/{lado}")
    public ResponseEntity<Resource> licencia(@PathVariable Long id, @PathVariable String lado) {
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_JPEG)
                .cacheControl(CacheControl.noCache())
                .body(licenciaService.leer(id, lado));
    }

    /**
     * Corrige los datos de la licencia (numero, categoria, vencimiento) y, si vienen, cambia una o las
     * dos fotos. Multipart: "datos" (JSON), "anverso" y "reverso" opcionales.
     */
    @PutMapping(value = "/{id}/licencia", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<PerfilConductorResponse>> actualizarLicencia(
            @PathVariable Long id,
            @Valid @RequestPart("datos") LicenciaRequest datos,
            @RequestPart(value = "anverso", required = false) MultipartFile anverso,
            @RequestPart(value = "reverso", required = false) MultipartFile reverso) {
        licenciaService.actualizarPorAdmin(id, datos, anverso, reverso);
        return ResponseEntity.ok(ApiResponse.exito("Licencia actualizada", perfilConductorService.obtenerPorConductor(id)));
    }

    /** QR de cobro que subio el conductor (de 0 a 3). */
    @GetMapping("/{id}/qr")
    public ResponseEntity<ApiResponse<List<QrPagoResponse>>> qr(@PathVariable Long id) {
        gestionConductorService.obtener(id);
        return ResponseEntity.ok(ApiResponse.exito(qrPagoConductorService.listar(id)));
    }

    @GetMapping("/{id}/qr/{idQr}/imagen")
    public ResponseEntity<Resource> imagenQr(@PathVariable Long id, @PathVariable Long idQr) {
        var qr = qrPagoConductorService.delConductor(id, idQr);
        return QrPagoConductorController.imagenQr(almacenamientoArchivos.leer(qr.getImagenUrl()), "qr_" + idQr + ".png");
    }

    /** Borrado logico de un QR del conductor. */
    @DeleteMapping("/{id}/qr/{idQr}")
    public ResponseEntity<ApiResponse<List<QrPagoResponse>>> eliminarQr(@PathVariable Long id, @PathVariable Long idQr) {
        qrPagoConductorService.eliminarDeConductor(id, idQr);
        return ResponseEntity.ok(ApiResponse.exito("QR eliminado", qrPagoConductorService.listar(id)));
    }
}
