package com.taxiuap.backend.pricing.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Coordinate;

import com.taxiuap.backend.pricing.dto.DesglosePrecioDelivery;
import com.taxiuap.backend.pricing.dto.RutaResponse;
import com.taxiuap.backend.shared.exception.NegocioException;

class CalculoPrecioDeliveryServiceTest {

    private static final GeometryFactory GEOMETRIA = new GeometryFactory();

    @Test
    void encomiendaCobraTarifaBaseYRecorridoSinCobrarPorMinuto() {
        CalculoPrecioDeliveryService service = new CalculoPrecioDeliveryService(
                (origen, destino) -> new RutaResponse(new BigDecimal("2500"), 600),
                new BigDecimal("8.00"), new BigDecimal("2.00"), new BigDecimal("99.00"));

        DesglosePrecioDelivery resultado = service.calcularEncomienda(punto(1, 2), punto(3, 4));

        assertEquals(new BigDecimal("13.00"), resultado.precioServicio());
        assertEquals(new BigDecimal("2.50"), resultado.distanciaKm());
        assertEquals(10, resultado.duracionMinutos());
        assertEquals(false, resultado.estimado());
    }

    @Test
    void compraEstimaGpsBYPrefijaComercioB() {
        CalculoPrecioDeliveryService service = new CalculoPrecioDeliveryService(
                (origen, destino) -> new RutaResponse(new BigDecimal("1000"), 120),
                new BigDecimal("4.00"), new BigDecimal("3.00"), BigDecimal.ZERO);

        DesglosePrecioDelivery estimado = service.estimarCompra(punto(1, 2), punto(3, 4));
        DesglosePrecioDelivery fijado = service.fijarPrecioCompra(punto(5, 6), punto(3, 4));

        assertEquals(new BigDecimal("7.00"), estimado.precioServicio());
        assertEquals(true, estimado.estimado());
        assertEquals(false, fijado.estimado());
    }

    @Test
    void falloDeOsrmImpideCalcularSinLineaRecta() {
        CalculoPrecioDeliveryService service = new CalculoPrecioDeliveryService(
                (origen, destino) -> { throw new NegocioException("OSRM no disponible"); },
                new BigDecimal("5.00"), BigDecimal.ONE, BigDecimal.ZERO);

        assertThrows(NegocioException.class, () -> service.calcularEncomienda(punto(1, 2), punto(3, 4)));
    }

    @Test
    void consolidarPagoNoCreaComisionAunqueLlegueUnPorcentajeConfigurado() {
        CalculoPrecioDeliveryService service = new CalculoPrecioDeliveryService(
                (origen, destino) -> new RutaResponse(new BigDecimal("1000"), 60),
                BigDecimal.ZERO, BigDecimal.ONE, BigDecimal.ZERO);

        DesglosePrecioDelivery resultado = service.consolidarPago(
                service.fijarPrecioCompra(punto(1, 2), punto(3, 4)), new BigDecimal("30.00"));

        assertEquals(new BigDecimal("31.00"), resultado.totalCliente());
    }

    @Test
    void compraSoloEsVisibleSiElMontoNoSuperaElLimite() {
        CalculoPrecioDeliveryService service = new CalculoPrecioDeliveryService(
                (origen, destino) -> new RutaResponse(BigDecimal.ONE, 1),
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO);

        assertEquals(true, service.puedeAdelantar(new BigDecimal("50.00"), new BigDecimal("50.00")));
        assertEquals(false, service.puedeAdelantar(new BigDecimal("50.01"), new BigDecimal("50.00")));
    }

    private Point punto(double x, double y) {
        return GEOMETRIA.createPoint(new Coordinate(x, y));
    }
}
