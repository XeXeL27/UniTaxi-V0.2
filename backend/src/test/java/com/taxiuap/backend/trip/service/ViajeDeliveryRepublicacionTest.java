package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.mock;

import java.math.BigDecimal;
import java.lang.reflect.Method;

import org.junit.jupiter.api.Test;
import org.locationtech.jts.geom.Point;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import com.taxiuap.backend.communication.service.NotificacionPushService;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.location.repository.UbicacionConductorRepository;
import com.taxiuap.backend.pricing.repository.BilleteraConductorRepository;
import com.taxiuap.backend.pricing.repository.ComisionRepository;
import com.taxiuap.backend.pricing.repository.PagoRepository;
import com.taxiuap.backend.pricing.service.CalculoPrecioService;
import com.taxiuap.backend.pricing.service.QrPagoConductorService;
import com.taxiuap.backend.rating.repository.CalificacionRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.trip.repository.DatosEntregaRepository;
import com.taxiuap.backend.trip.repository.OfertaViajeRepository;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.trip.repository.ViajeRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

class ViajeDeliveryRepublicacionTest {

    @Test
    void republicacionConservaDatosDeclarativosYCodigosPeroLimpiaOperativos() throws Exception {
        ViajeService service = new ViajeService(mock(ViajeRepository.class), mock(PasajeroRepository.class),
                mock(ConductorRepository.class), mock(VehiculoRepository.class), mock(PagoRepository.class),
                mock(ComisionRepository.class), mock(BilleteraConductorRepository.class),
                mock(CalculoPrecioService.class), mock(HistorialViajeService.class), mock(SimpMessagingTemplate.class),
                mock(CalificacionRepository.class), mock(QrPagoConductorService.class),
                mock(SolicitudViajeRepository.class), mock(DatosEntregaRepository.class),
                mock(OfertaViajeRepository.class), mock(UbicacionConductorRepository.class),
                mock(NotificacionPushService.class));
        Method metodo = ViajeService.class.getDeclaredMethod("copiarDatosEntregaParaRepublicar",
                DatosEntrega.class, SolicitudViaje.class);
        metodo.setAccessible(true);

        DatosEntrega anterior = new DatosEntrega();
        anterior.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        anterior.setDescripcion("Medicamento");
        anterior.setCostoProductoEstimado(new BigDecimal("25.00"));
        anterior.setCostoProductoReal(new BigDecimal("27.00"));
        anterior.setCodigoRecogida("123456");
        anterior.setCodigoEntrega("654321");
        anterior.setPuntoCompra(mock(Point.class));
        anterior.setDetalleCompra("Tienda real");
        anterior.setEstadoEntrega(EstadoEntrega.EN_MANO);

        DatosEntrega nueva = (DatosEntrega) metodo.invoke(service, anterior, new SolicitudViaje());

        assertEquals(TipoEnvio.COMPRA_Y_ENTREGA, nueva.getTipoEnvio());
        assertEquals("123456", nueva.getCodigoRecogida());
        assertEquals("654321", nueva.getCodigoEntrega());
        assertEquals(EstadoEntrega.PENDIENTE_RECOGIDA, nueva.getEstadoEntrega());
        assertNull(nueva.getCostoProductoReal());
        assertNull(nueva.getPuntoCompra());
        assertNull(nueva.getDetalleCompra());
        assertEquals(EstadoRegistro.A, nueva.getEstadoDatosEntrega());
    }
}
