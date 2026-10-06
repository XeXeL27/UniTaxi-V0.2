package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.enums.TipoFotoEntrega;
import com.taxiuap.backend.trip.service.EntregaService;
import com.taxiuap.backend.trip.service.ViajeService;

import lombok.RequiredArgsConstructor;

/** Pedidos DELIVERY en el panel: lista general y fotos de la evidencia de cada entrega. */
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class EntregaAdminController {

    private final ViajeService viajeService;
    private final EntregaService entregaService;

    @GetMapping("/entregas")
    public ResponseEntity<ApiResponse<List<ViajeResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.listarEntregas()));
    }

    /** Foto de la evidencia: PAQUETE, RECOGIDA, COMPROBANTE, ENTREGA o FALLA. */
    @GetMapping("/viajes/{id}/entrega/foto/{tipo}")
    public ResponseEntity<Resource> foto(@PathVariable Long id, @PathVariable TipoFotoEntrega tipo) {
        return ResponseEntity.ok().cacheControl(CacheControl.noCache())
                .contentType(MediaType.IMAGE_JPEG).body(entregaService.fotoParaAdmin(id, tipo));
    }
}
