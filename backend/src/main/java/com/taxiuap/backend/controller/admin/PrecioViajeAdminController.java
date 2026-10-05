package com.taxiuap.backend.controller.admin;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.pricing.dto.DescuentoEstudianteRequest;
import com.taxiuap.backend.pricing.dto.ParametrosPrecio;
import com.taxiuap.backend.pricing.dto.PrecioBaseRequest;
import com.taxiuap.backend.pricing.dto.TramoPrecioRequest;
import com.taxiuap.backend.pricing.service.ParametrosPrecioService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Tarifas del panel: precio base y tramos de km adicionales del viaje en taxi (Precio del viaje) y
 * descuento fijo del estudiante UAP (Descuento estudiante). Todas responden los parametros vigentes.
 */
@RestController
@RequestMapping("/api/admin/precio-viaje")
@RequiredArgsConstructor
public class PrecioViajeAdminController {

    private final ParametrosPrecioService parametrosPrecioService;

    @GetMapping
    public ResponseEntity<ApiResponse<ParametrosPrecio>> actual() {
        return ResponseEntity.ok(ApiResponse.exito(parametrosPrecioService.actuales()));
    }

    @PutMapping("/base")
    public ResponseEntity<ApiResponse<ParametrosPrecio>> guardarBase(@Valid @RequestBody PrecioBaseRequest datos) {
        return ResponseEntity.ok(ApiResponse.exito("Precio base guardado", parametrosPrecioService.guardarBase(datos)));
    }

    @PostMapping("/tramos")
    public ResponseEntity<ApiResponse<ParametrosPrecio>> crearTramo(@Valid @RequestBody TramoPrecioRequest datos) {
        return ResponseEntity.ok(ApiResponse.exito("Km extra agregados", parametrosPrecioService.crearTramo(datos)));
    }

    @PutMapping("/tramos/{id}")
    public ResponseEntity<ApiResponse<ParametrosPrecio>> editarTramo(@PathVariable Integer id,
            @Valid @RequestBody TramoPrecioRequest datos) {
        return ResponseEntity.ok(ApiResponse.exito("Tramo guardado", parametrosPrecioService.editarTramo(id, datos)));
    }

    /** Borrado logico (estado_tramo X). */
    @DeleteMapping("/tramos/{id}")
    public ResponseEntity<ApiResponse<ParametrosPrecio>> eliminarTramo(@PathVariable Integer id) {
        return ResponseEntity.ok(ApiResponse.exito("Tramo eliminado", parametrosPrecioService.eliminarTramo(id)));
    }

    @PutMapping("/descuento-estudiante")
    public ResponseEntity<ApiResponse<ParametrosPrecio>> guardarDescuento(
            @Valid @RequestBody DescuentoEstudianteRequest datos) {
        return ResponseEntity.ok(ApiResponse.exito("Descuento de estudiante guardado",
                parametrosPrecioService.guardarDescuento(datos)));
    }
}
