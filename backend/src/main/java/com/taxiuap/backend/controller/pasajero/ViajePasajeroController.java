package com.taxiuap.backend.controller.pasajero;

import java.util.List;

import org.springframework.core.io.Resource;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.controller.conductor.QrPagoConductorController;
import com.taxiuap.backend.pricing.dto.QrPagoResponse;
import com.taxiuap.backend.pricing.entity.QrPagoConductor;
import com.taxiuap.backend.pricing.service.QrPagoConductorService;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.trip.dto.CambioMetodoPagoRequest;
import com.taxiuap.backend.trip.dto.CancelarViajeRequest;
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.service.ViajeService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Viajes del pasajero autenticado. */
@RestController
@RequestMapping("/api/pasajero/viajes")
@RequiredArgsConstructor
public class ViajePasajeroController {

    private final ViajeService viajeService;
    private final QrPagoConductorService qrPagoConductorService;
    private final AlmacenamientoArchivos almacenamientoArchivos;

    @GetMapping
    public ResponseEntity<ApiResponse<List<ViajeResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.listarDelPasajero()));
    }

    @GetMapping("/en-curso")
    public ResponseEntity<ApiResponse<ViajeResponse>> enCurso() {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.enCurso().orElse(null)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<ViajeResponse>> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.obtener(id)));
    }

    @PostMapping("/{id}/cancelar")
    public ResponseEntity<ApiResponse<ViajeResponse>> cancelar(
            @PathVariable Long id, @RequestBody(required = false) CancelarViajeRequest request) {
        ViajeResponse cancelado = viajeService.cancelar(id, request);
        return ResponseEntity.ok(ApiResponse.exito("Viaje cancelado", cancelado));
    }

    /** Pide al conductor pagar de otra forma; el cambio vale cuando el conductor lo acepta. */
    @PostMapping("/{id}/metodo-pago")
    public ResponseEntity<ApiResponse<ViajeResponse>> pedirCambioMetodoPago(
            @PathVariable Long id, @Valid @RequestBody CambioMetodoPagoRequest request) {
        return ResponseEntity.ok(ApiResponse.exito("Se pidio al conductor el cambio de pago",
                viajeService.pedirCambioMetodoPago(id, request.metodoPago())));
    }

    /** QR de cobro del conductor del viaje. */
    @GetMapping("/{id}/qr")
    public ResponseEntity<ApiResponse<List<QrPagoResponse>>> qrConductor(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(qrPagoConductorService.listarDeViaje(UsuarioActual.idUsuario(), id)));
    }

    @GetMapping("/{id}/qr/{idQr}/imagen")
    public ResponseEntity<Resource> imagenQr(@PathVariable Long id, @PathVariable Long idQr) {
        QrPagoConductor qr = qrPagoConductorService.obtenerDeViaje(UsuarioActual.idUsuario(), id, idQr);
        return QrPagoConductorController.imagenQr(almacenamientoArchivos.leer(qr.getImagenUrl()), "qr_conductor_" + idQr + ".png");
    }
}
