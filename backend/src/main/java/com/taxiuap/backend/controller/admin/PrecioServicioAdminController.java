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

import com.taxiuap.backend.pricing.dto.ParametrosPrecio;
import com.taxiuap.backend.pricing.dto.PrecioBaseRequest;
import com.taxiuap.backend.pricing.dto.TramoPrecioRequest;
import com.taxiuap.backend.pricing.enums.ServicioPrecio;
import com.taxiuap.backend.pricing.service.ParametrosPrecioService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Tabla de precios por km de cada servicio en el panel (Tarifas > Precio del viaje, del paquete y del
 * delivery): precio base y tramos de km extra, igual para los tres. {servicio} es TAXI, PAQUETE o
 * DELIVERY. Todas responden la tabla vigente del servicio. El descuento de estudiante sigue en
 * /api/admin/precio-viaje (solo el moto taxi).
 */
@RestController
@RequestMapping("/api/admin/precios/{servicio}")
@RequiredArgsConstructor
public class PrecioServicioAdminController {

    private final ParametrosPrecioService parametrosPrecioService;

    @GetMapping
    public ResponseEntity<ApiResponse<ParametrosPrecio>> actual(@PathVariable ServicioPrecio servicio) {
        return ResponseEntity.ok(ApiResponse.exito(parametrosPrecioService.actuales(servicio)));
    }

    @PutMapping("/base")
    public ResponseEntity<ApiResponse<ParametrosPrecio>> guardarBase(@PathVariable ServicioPrecio servicio,
            @Valid @RequestBody PrecioBaseRequest datos) {
        return ResponseEntity.ok(ApiResponse.exito("Precio base guardado",
                parametrosPrecioService.guardarBase(servicio, datos)));
    }

    @PostMapping("/tramos")
    public ResponseEntity<ApiResponse<ParametrosPrecio>> crearTramo(@PathVariable ServicioPrecio servicio,
            @Valid @RequestBody TramoPrecioRequest datos) {
        return ResponseEntity.ok(ApiResponse.exito("Km extra agregados",
                parametrosPrecioService.crearTramo(servicio, datos)));
    }

    @PutMapping("/tramos/{id}")
    public ResponseEntity<ApiResponse<ParametrosPrecio>> editarTramo(@PathVariable ServicioPrecio servicio,
            @PathVariable Integer id, @Valid @RequestBody TramoPrecioRequest datos) {
        return ResponseEntity.ok(ApiResponse.exito("Tramo guardado",
                parametrosPrecioService.editarTramo(servicio, id, datos)));
    }

    /** Borrado logico (estado_tramo X). */
    @DeleteMapping("/tramos/{id}")
    public ResponseEntity<ApiResponse<ParametrosPrecio>> eliminarTramo(@PathVariable ServicioPrecio servicio,
            @PathVariable Integer id) {
        return ResponseEntity.ok(ApiResponse.exito("Tramo eliminado",
                parametrosPrecioService.eliminarTramo(servicio, id)));
    }
}
