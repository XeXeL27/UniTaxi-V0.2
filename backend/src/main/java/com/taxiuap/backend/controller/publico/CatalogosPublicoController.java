package com.taxiuap.backend.controller.publico;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.institution.dto.CarreraResponse;
import com.taxiuap.backend.institution.dto.InstitucionResponse;
import com.taxiuap.backend.institution.dto.TipoInstitucionResponse;
import com.taxiuap.backend.institution.service.CarreraService;
import com.taxiuap.backend.institution.service.InstitucionService;
import com.taxiuap.backend.institution.service.TipoInstitucionService;
import com.taxiuap.backend.rating.dto.EtiquetaCalificacionResponse;
import com.taxiuap.backend.rating.enums.AplicaA;
import com.taxiuap.backend.rating.service.EtiquetaCalificacionService;
import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.vehicle.dto.CategoriaServicioResponse;
import com.taxiuap.backend.vehicle.dto.TipoVehiculoResponse;
import com.taxiuap.backend.vehicle.service.CategoriaServicioService;
import com.taxiuap.backend.vehicle.service.TipoVehiculoService;

import lombok.RequiredArgsConstructor;

/** Lectura publica de catalogos, sin autenticacion. Solo devuelve registros en estado A. */
@RestController
@RequestMapping("/api/publico")
@RequiredArgsConstructor
public class CatalogosPublicoController {

    private final TipoInstitucionService tipoInstitucionService;
    private final InstitucionService institucionService;
    private final CarreraService carreraService;
    private final TipoVehiculoService tipoVehiculoService;
    private final CategoriaServicioService categoriaServicioService;
    private final EtiquetaCalificacionService etiquetaCalificacionService;

    @GetMapping("/instituciones")
    public ResponseEntity<ApiResponse<List<InstitucionResponse>>> listarInstituciones(
            @RequestParam(required = false) Integer idTipoInstitucion) {
        List<InstitucionResponse> instituciones = idTipoInstitucion != null
                ? institucionService.listarPorTipo(idTipoInstitucion)
                : institucionService.listar(false);
        return ResponseEntity.ok(ApiResponse.exito(instituciones));
    }

    @GetMapping("/instituciones/{id}/carreras")
    public ResponseEntity<ApiResponse<List<CarreraResponse>>> listarCarrerasDeInstitucion(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(carreraService.listarPorInstitucion(id)));
    }

    @GetMapping("/tipos-institucion")
    public ResponseEntity<ApiResponse<List<TipoInstitucionResponse>>> listarTiposInstitucion() {
        return ResponseEntity.ok(ApiResponse.exito(tipoInstitucionService.listar(false)));
    }

    @GetMapping("/tipos-vehiculo")
    public ResponseEntity<ApiResponse<List<TipoVehiculoResponse>>> listarTiposVehiculo() {
        return ResponseEntity.ok(ApiResponse.exito(tipoVehiculoService.listar(false)));
    }

    @GetMapping("/categorias-servicio")
    public ResponseEntity<ApiResponse<List<CategoriaServicioResponse>>> listarCategoriasServicio(
            @RequestParam(required = false) Integer idTipoVehiculo) {
        List<CategoriaServicioResponse> categorias = idTipoVehiculo != null
                ? categoriaServicioService.listarPorTipoVehiculo(idTipoVehiculo)
                : categoriaServicioService.listar(false);
        return ResponseEntity.ok(ApiResponse.exito(categorias));
    }

    @GetMapping("/etiquetas-calificacion")
    public ResponseEntity<ApiResponse<List<EtiquetaCalificacionResponse>>> listarEtiquetasCalificacion(
            @RequestParam(required = false) AplicaA aplicaA) {
        List<EtiquetaCalificacionResponse> etiquetas = aplicaA != null
                ? etiquetaCalificacionService.listarPorAplicaA(aplicaA)
                : etiquetaCalificacionService.listar(false);
        return ResponseEntity.ok(ApiResponse.exito(etiquetas));
    }
}
