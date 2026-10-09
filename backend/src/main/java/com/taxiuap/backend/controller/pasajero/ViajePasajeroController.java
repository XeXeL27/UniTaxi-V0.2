package com.taxiuap.backend.controller.pasajero;

import java.util.List;

import org.springframework.core.io.Resource;
import org.springframework.http.ResponseEntity;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.controller.conductor.QrPagoConductorController;
import com.taxiuap.backend.location.dto.UbicacionConductorViajeResponse;
import com.taxiuap.backend.pricing.dto.QrPagoResponse;
import com.taxiuap.backend.pricing.entity.QrPagoConductor;
import com.taxiuap.backend.pricing.service.QrPagoConductorService;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.dto.CambioMetodoPagoRequest;
import com.taxiuap.backend.trip.dto.CancelarViajeRequest;
import com.taxiuap.backend.trip.dto.HistorialViajesResponse;
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.dto.ViajesActivosResponse;
import com.taxiuap.backend.trip.enums.PeriodoHistorial;
import com.taxiuap.backend.trip.service.EntregaService;
import com.taxiuap.backend.trip.service.ViajeService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Viajes del pasajero autenticado. */
@RestController
@RequestMapping("/api/pasajero/viajes")
@RequiredArgsConstructor
public class ViajePasajeroController {

    private final ViajeService viajeService;
    private final EntregaService entregaService;
    private final QrPagoConductorService qrPagoConductorService;
    private final AlmacenamientoArchivos almacenamientoArchivos;

    @GetMapping
    public ResponseEntity<ApiResponse<List<ViajeResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.listarDelPasajero()));
    }

    /** Historial de la app: solo viajes completados, los ultimos 10 o un mes paginado. */
    @GetMapping("/historial")
    public ResponseEntity<ApiResponse<HistorialViajesResponse>> historial(
            @RequestParam(defaultValue = "RECIENTES") PeriodoHistorial periodo,
            @RequestParam(defaultValue = "0") int pagina) {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.historialDelPasajero(periodo, pagina)));
    }

    /** El cuadro para calificar ya se mostro: no se vuelve a ofrecer (ni tras cerrar sesion). */
    @PostMapping("/{id}/calificacion/ofrecida")
    public ResponseEntity<ApiResponse<Void>> calificacionOfrecida(@PathVariable Long id) {
        viajeService.marcarCalificacionOfrecida(id);
        return ResponseEntity.ok(ApiResponse.exito("Calificacion ofrecida", null));
    }

    /** Servicios en curso (hasta 2 del pasajero, hasta 3 pedidos del repartidor) y el maximo permitido. */
    @GetMapping("/activos")
    public ResponseEntity<ApiResponse<ViajesActivosResponse>> activos() {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.activosDelPasajero()));
    }

    @GetMapping("/en-curso")
    public ResponseEntity<ApiResponse<ViajeResponse>> enCurso() {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.enCurso().orElse(null)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<ViajeResponse>> obtener(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.obtener(id)));
    }

    /** Posicion del conductor asignado, para que el pasajero vea de donde viene y cuanto tarda. */
    @GetMapping("/{id}/ubicacion-conductor")
    public ResponseEntity<ApiResponse<UbicacionConductorViajeResponse>> ubicacionConductor(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.ubicacionConductorSeguimiento(id)));
    }

    @PostMapping("/{id}/cancelar")
    public ResponseEntity<ApiResponse<ViajeResponse>> cancelar(
            @PathVariable Long id, @RequestBody(required = false) CancelarViajeRequest request) {
        ViajeResponse cancelado = viajeService.cancelar(id, request);
        return ResponseEntity.ok(ApiResponse.exito("Viaje cancelado", cancelado));
    }

    /**
     * COMPRA_Y_ENTREGA: el cliente confirma el comercio y el monto que propuso el repartidor. Sin esta
     * confirmacion el repartidor no puede comprar, y si el costo real se pasa hace falta confirmar otra
     * vez. No aplica a ENCOMIENDA, donde no hay nada que comprar.
     */
    @PostMapping("/{id}/entrega/confirmar-compra")
    public ResponseEntity<ApiResponse<ViajeResponse>> confirmarCompra(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito("Compra confirmada", entregaService.confirmarCompra(id)));
    }

    /** Viaje pedido para otra persona y pagado por quien lo pidio: "Ya pague" por el QR del conductor. */
    @PostMapping("/{id}/pago-avisado")
    public ResponseEntity<ApiResponse<ViajeResponse>> pagoAvisado(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.exito("Avisamos al conductor que ya pagaste", viajeService.avisarPago(id)));
    }

    /** Foto que tomo el repartidor al entregar el paquete: la confirmacion de que llego. */
    @GetMapping("/{id}/entrega/foto-entrega")
    public ResponseEntity<Resource> fotoEntrega(@PathVariable Long id) {
        return ResponseEntity.ok().cacheControl(org.springframework.http.CacheControl.noCache())
                .contentType(org.springframework.http.MediaType.IMAGE_JPEG)
                .body(entregaService.fotoEntregaParaCliente(id));
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

    /** Comprobante de la compra, visible únicamente para el pasajero propietario del viaje. */
    @GetMapping("/{id}/entrega/comprobante")
    public ResponseEntity<Resource> comprobanteEntrega(@PathVariable Long id) {
        DatosEntrega datos = viajeService.obtenerViajeDelPasajero(id).getSolicitud().getDatosEntrega();
        if (datos == null || datos.getFotoComprobanteUrl() == null || datos.getFotoComprobanteUrl().isBlank()) {
            throw new RecursoNoEncontradoException("El pedido no tiene comprobante");
        }
        return ResponseEntity.ok().cacheControl(CacheControl.noCache())
                .contentType(MediaType.IMAGE_JPEG)
                .body(almacenamientoArchivos.leer(datos.getFotoComprobanteUrl()));
    }
}
