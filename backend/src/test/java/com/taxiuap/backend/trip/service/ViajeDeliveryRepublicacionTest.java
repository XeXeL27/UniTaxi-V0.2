package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.lang.reflect.Method;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.locationtech.jts.geom.Point;
import org.mockito.ArgumentCaptor;
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
import com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryService;
import com.taxiuap.backend.pricing.service.QrPagoConductorService;
import com.taxiuap.backend.rating.repository.CalificacionRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.ProductoEntrega;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.SituacionProducto;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.trip.repository.DatosEntregaRepository;
import com.taxiuap.backend.trip.repository.OfertaViajeRepository;
import com.taxiuap.backend.trip.repository.ProductoEntregaRepository;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.trip.repository.ViajeRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

class ViajeDeliveryRepublicacionTest {

    @Test
    void republicacionConservaDatosDeclarativosYCodigosPeroLimpiaOperativos() throws Exception {
        ViajeService service = servicio(mock(ProductoEntregaRepository.class));
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
        anterior.setTarifaBaseAplicada(new BigDecimal("8.00"));
        anterior.setPrecioKmAplicado(new BigDecimal("2.00"));

        DatosEntrega nueva = (DatosEntrega) metodo.invoke(service, anterior, new SolicitudViaje());

        assertEquals(TipoEnvio.COMPRA_Y_ENTREGA, nueva.getTipoEnvio());
        assertEquals("123456", nueva.getCodigoRecogida());
        assertEquals("654321", nueva.getCodigoEntrega());
        assertEquals(EstadoEntrega.PENDIENTE_RECOGIDA, nueva.getEstadoEntrega());
        assertNull(nueva.getCostoProductoReal());
        assertNull(nueva.getPuntoCompra());
        assertNull(nueva.getDetalleCompra());
        assertEquals(EstadoRegistro.A, nueva.getEstadoDatosEntrega());
        // La tarifa del pedido original sigue valiendo.
        assertEquals(new BigDecimal("8.00"), nueva.getTarifaBaseAplicada());
        assertEquals(new BigDecimal("2.00"), nueva.getPrecioKmAplicado());
    }

    @Test
    void unaCompraPublicadaDeNuevoConservaLaListaSinLoQueCompraElQueCancelo() throws Exception {
        ProductoEntregaRepository productos = mock(ProductoEntregaRepository.class);
        ViajeService service = servicio(productos);
        Method metodo = ViajeService.class.getDeclaredMethod("copiarProductosParaRepublicar",
                DatosEntrega.class, DatosEntrega.class);
        metodo.setAccessible(true);

        DatosEntrega anterior = new DatosEntrega();
        anterior.setId(1L);
        anterior.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        ProductoEntrega pan = new ProductoEntrega();
        pan.setOrden(1);
        pan.setNombre("Pan");
        pan.setCantidad(3);
        pan.setIndicaciones("Del horno");
        pan.setSituacionProducto(SituacionProducto.CONSEGUIDO);
        pan.setCantidadConseguida(3);
        pan.setPrecioUnitario(new BigDecimal("0.50"));
        pan.setSubtotal(new BigDecimal("1.50"));
        when(productos.findByDatosEntregaIdAndEstadoProductoEntregaOrderByOrdenAscIdAsc(1L, EstadoRegistro.A))
                .thenReturn(List.of(pan));
        when(productos.save(any(ProductoEntrega.class))).thenAnswer(i -> i.getArgument(0));
        DatosEntrega nueva = new DatosEntrega();

        metodo.invoke(service, anterior, nueva);

        ArgumentCaptor<ProductoEntrega> guardado = ArgumentCaptor.forClass(ProductoEntrega.class);
        verify(productos).save(guardado.capture());
        ProductoEntrega copia = guardado.getValue();
        assertSame(nueva, copia.getDatosEntrega());
        assertEquals("Pan", copia.getNombre());
        assertEquals(3, copia.getCantidad());
        assertEquals("Del horno", copia.getIndicaciones());
        assertEquals(SituacionProducto.PENDIENTE, copia.getSituacionProducto());
        assertNull(copia.getPrecioUnitario());
        assertNull(copia.getSubtotal());
        assertEquals(1, nueva.getProductos().size());
    }

    private static ViajeService servicio(ProductoEntregaRepository productos) {
        return new ViajeService(mock(ViajeRepository.class), mock(PasajeroRepository.class),
                mock(ConductorRepository.class), mock(VehiculoRepository.class), mock(PagoRepository.class),
                mock(ComisionRepository.class), mock(BilleteraConductorRepository.class),
                mock(CalculoPrecioService.class), mock(CalculoPrecioDeliveryService.class),
                mock(HistorialViajeService.class), mock(SimpMessagingTemplate.class),
                mock(CalificacionRepository.class), mock(QrPagoConductorService.class),
                mock(SolicitudViajeRepository.class), mock(DatosEntregaRepository.class),
                mock(OfertaViajeRepository.class), mock(UbicacionConductorRepository.class),
                mock(NotificacionPushService.class), productos);
    }
}
