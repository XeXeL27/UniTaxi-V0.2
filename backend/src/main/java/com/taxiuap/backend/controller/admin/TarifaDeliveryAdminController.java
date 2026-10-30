package com.taxiuap.backend.controller.admin;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.pricing.dto.TarifaDelivery;
import com.taxiuap.backend.pricing.dto.TarifaDeliveryRequest;
import com.taxiuap.backend.pricing.service.TarifaDeliveryService;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Tarifas > Tarifa del delivery: tarifa base y precio por km de la encomienda y la compra. Vale para los
 * pedidos nuevos; los anteriores conservan la que tenian al pedirlos.
 */
@RestController
@RequestMapping("/api/admin/precio-delivery")
@RequiredArgsConstructor
public class TarifaDeliveryAdminController {

    private final TarifaDeliveryService tarifaDeliveryService;

    @GetMapping
    public ResponseEntity<ApiResponse<TarifaDelivery>> actual() {
        return ResponseEntity.ok(ApiResponse.exito(tarifaDeliveryService.actual()));
    }

    @PutMapping
    public ResponseEntity<ApiResponse<TarifaDelivery>> guardar(@Valid @RequestBody TarifaDeliveryRequest datos) {
        return ResponseEntity.ok(ApiResponse.exito("Tarifa del delivery guardada", tarifaDeliveryService.guardar(datos)));
    }
}
