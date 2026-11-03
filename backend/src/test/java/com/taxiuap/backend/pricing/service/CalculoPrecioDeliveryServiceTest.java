package com.taxiuap.backend.pricing.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Coordinate;

import com.taxiuap.backend.pricing.dto.DesglosePrecioDelivery;
import com.taxiuap.backend.pricing.dto.RutaResponse;
import com.taxiuap.backend.pricing.dto.TarifaDelivery;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.shared.exception.NegocioException;

class CalculoPrecioDeliveryServiceTest {

    private static final GeometryFactory GEOMETRIA = new GeometryFactory();

    @Test
    void encomiendaCobraTarifaBaseYRecorrido() {
        CalculoPrecioDeliveryService service = servicio(
                (origen, destino) -> new RutaResponse(new BigDecimal("2500"), 600),
                new BigDecimal("8.00"), new BigDecimal("2.00"));

        DesglosePrecioDelivery resultado = service.calcularEncomienda(punto(1, 2), punto(3, 4));

        assertEquals(new BigDecimal("13.00"), resultado.precioServicio());
        assertEquals(new BigDecimal("2.50"), resultado.distanciaKm());
        assertEquals(10, resultado.duracionMinutos());
        assertEquals(false, resultado.estimado());
    }

    @Test
    void compraEstimaGpsBYPrefijaComercioB() {
        CalculoPrecioDeliveryService service = servicio(
                (origen, destino) -> new RutaResponse(new BigDecimal("1000"), 120),
                new BigDecimal("4.00"), new BigDecimal("3.00"));

        DesglosePrecioDelivery estimado = service.estimarCompra(punto(1, 2), punto(3, 4), service.tarifaVigente());
        DesglosePrecioDelivery fijado = service.fijarPrecioCompra(punto(5, 6), punto(3, 4), service.tarifaVigente());

        assertEquals(new BigDecimal("7.00"), estimado.precioServicio());
        assertEquals(true, estimado.estimado());
        assertEquals(false, fijado.estimado());
    }

    @Test
    void falloDeOsrmImpideCalcularSinLineaRecta() {
        CalculoPrecioDeliveryService service = servicio(
                (origen, destino) -> { throw new NegocioException("OSRM no disponible"); },
                new BigDecimal("5.00"), BigDecimal.ONE);

        assertThrows(NegocioException.class, () -> service.calcularEncomienda(punto(1, 2), punto(3, 4)));
    }

    @Test
    void consolidarPagoNoCreaComisionAunqueLlegueUnPorcentajeConfigurado() {
        CalculoPrecioDeliveryService service = servicio(
                (origen, destino) -> new RutaResponse(new BigDecimal("1000"), 60),
                BigDecimal.ZERO, BigDecimal.ONE);

        DesglosePrecioDelivery resultado = service.consolidarPago(
                service.fijarPrecioCompra(punto(1, 2), punto(3, 4), service.tarifaVigente()), new BigDecimal("30.00"));

        assertEquals(new BigDecimal("31.00"), resultado.totalCliente());
    }

    @Test
    void compraSoloEsVisibleSiElMontoNoSuperaElLimite() {
        CalculoPrecioDeliveryService service = servicio(
                (origen, destino) -> new RutaResponse(BigDecimal.ONE, 1),
                BigDecimal.ZERO, BigDecimal.ZERO);

        assertEquals(true, service.puedeAdelantar(new BigDecimal("50.00"), new BigDecimal("50.00")));
        assertEquals(false, service.puedeAdelantar(new BigDecimal("50.01"), new BigDecimal("50.00")));
    }

    @Test
    void pedidoUsaLaTarifaCopiadaAunqueElPanelLaCambie() {
        CalculoPrecioDeliveryService service = servicio(
                (origen, destino) -> new RutaResponse(new BigDecimal("1000"), 60),
                new BigDecimal("10.00"), new BigDecimal("3.00"));
        DatosEntrega datos = new DatosEntrega();
        datos.setTarifaBaseAplicada(new BigDecimal("8.00"));
        datos.setPrecioKmAplicado(new BigDecimal("2.00"));

        DesglosePrecioDelivery conCopia = service.fijarPrecioCompra(punto(1, 2), punto(3, 4), service.tarifaDe(datos));
        DesglosePrecioDelivery sinCopia = service.fijarPrecioCompra(punto(1, 2), punto(3, 4),
                service.tarifaDe(new DatosEntrega()));

        assertEquals(new BigDecimal("10.00"), conCopia.precioServicio());
        assertEquals(new BigDecimal("13.00"), sinCopia.precioServicio());
    }

    @Test
    void elPaqueteSeCotizaConSuTarifaYLaCompraConLaDelDelivery() {
        TarifaDeliveryService tarifas = mock(TarifaDeliveryService.class);
        TarifaDelivery delivery = new TarifaDelivery(new BigDecimal("8.00"), new BigDecimal("2.00"));
        TarifaDelivery paquete = new TarifaDelivery(new BigDecimal("5.00"), new BigDecimal("1.00"));
        when(tarifas.actual()).thenReturn(delivery);
        when(tarifas.de(TipoEnvio.COMPRA_Y_ENTREGA)).thenReturn(delivery);
        when(tarifas.de(TipoEnvio.ENCOMIENDA)).thenReturn(paquete);
        CalculoPrecioDeliveryService service = new CalculoPrecioDeliveryService(
                (origen, destino) -> new RutaResponse(new BigDecimal("3000"), 300), tarifas);

        assertEquals(new BigDecimal("8.00"), service.calcularEncomienda(punto(1, 2), punto(3, 4)).precioServicio());
        DatosEntrega paqueteViejo = new DatosEntrega();
        paqueteViejo.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        DatosEntrega compraVieja = new DatosEntrega();
        compraVieja.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        // Pedidos de antes de copiar la tarifa: la vigente de su tipo.
        assertEquals(paquete, service.tarifaDe(paqueteViejo));
        assertEquals(delivery, service.tarifaDe(compraVieja));
    }

    private CalculoPrecioDeliveryService servicio(ClienteRutas rutas, BigDecimal base, BigDecimal km) {
        TarifaDeliveryService tarifas = mock(TarifaDeliveryService.class);
        when(tarifas.actual()).thenReturn(new TarifaDelivery(base, km));
        when(tarifas.de(any())).thenReturn(new TarifaDelivery(base, km));
        return new CalculoPrecioDeliveryService(rutas, tarifas);
    }

    private Point punto(double x, double y) {
        return GEOMETRIA.createPoint(new Coordinate(x, y));
    }
}
