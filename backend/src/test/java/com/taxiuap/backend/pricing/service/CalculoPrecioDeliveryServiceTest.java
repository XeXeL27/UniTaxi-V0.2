package com.taxiuap.backend.pricing.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;

import com.taxiuap.backend.pricing.dto.DesglosePrecioDelivery;
import com.taxiuap.backend.pricing.dto.ParametrosPrecio;
import com.taxiuap.backend.pricing.dto.RutaResponse;
import com.taxiuap.backend.pricing.dto.TarifaDelivery;
import com.taxiuap.backend.pricing.enums.ServicioPrecio;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;

class CalculoPrecioDeliveryServiceTest {

    private static final GeometryFactory GEOMETRIA = new GeometryFactory();

    /** Hasta 1 km 8 Bs y cada km mas +2 Bs (la tabla inicial que sale de 8 Bs + 2 Bs por km). */
    private static final ParametrosPrecio DELIVERY = tabla("8", "1", "1", "2");
    /** Hasta 2 km 5 Bs, +1 km +1 Bs. */
    private static final ParametrosPrecio PAQUETE = tabla("5", "2", "1", "1");

    @Test
    void elPaqueteSeCobraConSuTablaEnBsEnteros() {
        CalculoPrecioDeliveryService service = servicio(metros("2500"));

        DesglosePrecioDelivery resultado = service.calcularEncomienda(punto(1, 2), punto(3, 4));

        // 2,5 km: base 5 Bs hasta 2 km y el tramo empezado +1 Bs.
        assertEquals(new BigDecimal("6.00"), resultado.precioServicio());
        assertEquals(new BigDecimal("2.50"), resultado.distanciaKm());
        assertEquals(false, resultado.estimado());
    }

    @Test
    void comprarAlLadoDelClienteCobraElBaseSinCentavos() {
        // El caso de produccion: el repartidor registro la compra a 10 m del cliente y salian 8,02 Bs.
        CalculoPrecioDeliveryService service = servicio(metros("10"));

        DesglosePrecioDelivery envio = service.fijarPrecioCompra(punto(1, 2), punto(3, 4), service.tarifaVigente());

        assertEquals(new BigDecimal("8.00"), envio.precioServicio());
        assertEquals(new BigDecimal("28.00"),
                service.consolidarPago(envio, new BigDecimal("20.00")).totalCliente());
    }

    @Test
    void cadaTramoEmpezadoSumaSuCostoYElUltimoSeRepite() {
        assertEquals(new BigDecimal("8.00"), servicio(metros("1000")).fijarPrecioCompra(punto(1, 2), punto(3, 4),
                DELIVERY).precioServicio());
        assertEquals(new BigDecimal("10.00"), servicio(metros("1300")).fijarPrecioCompra(punto(1, 2), punto(3, 4),
                DELIVERY).precioServicio());
        assertEquals(new BigDecimal("14.00"), servicio(metros("3200")).fijarPrecioCompra(punto(1, 2), punto(3, 4),
                DELIVERY).precioServicio());
    }

    @Test
    void compraEstimaYFijaConLaTablaDelDelivery() {
        CalculoPrecioDeliveryService service = servicio(metros("1500"));

        DesglosePrecioDelivery estimado = service.estimarCompra(punto(1, 2), punto(3, 4), service.tarifaVigente());
        DesglosePrecioDelivery fijado = service.fijarPrecioCompra(punto(5, 6), punto(3, 4), service.tarifaVigente());

        assertEquals(new BigDecimal("10.00"), estimado.precioServicio());
        assertEquals(true, estimado.estimado());
        assertEquals(false, fijado.estimado());
    }

    @Test
    void falloDeOsrmImpideCalcularSinLineaRecta() {
        CalculoPrecioDeliveryService service = new CalculoPrecioDeliveryService(
                (origen, destino) -> { throw new NegocioException("OSRM no disponible"); }, tablas());

        assertThrows(NegocioException.class, () -> service.calcularEncomienda(punto(1, 2), punto(3, 4)));
    }

    @Test
    void compraSoloEsVisibleSiElMontoNoSuperaElLimite() {
        CalculoPrecioDeliveryService service = servicio(metros("1"));

        assertEquals(true, service.puedeAdelantar(new BigDecimal("50.00"), new BigDecimal("50.00")));
        assertEquals(false, service.puedeAdelantar(new BigDecimal("50.01"), new BigDecimal("50.00")));
    }

    @Test
    void elPedidoUsaLaCopiaDeSuTablaAunqueElPanelLaCambie() {
        CalculoPrecioDeliveryService service = servicio(metros("1500"));
        DatosEntrega datos = new DatosEntrega();
        datos.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        // Copia de una tabla mas barata: hasta 3 km 6 Bs.
        datos.setTarifaAplicadaJson(service.copiaDeTarifa(tabla("6", "3", "1", "1")));

        assertEquals(new BigDecimal("6.00"),
                service.fijarPrecioCompra(punto(1, 2), punto(3, 4), service.tarifaDe(datos)).precioServicio());
        assertEquals("6 Bs hasta 3 km, +1 Bs cada 1 km", CalculoPrecioDeliveryService.textoTarifaGuardada(datos));
    }

    @Test
    void losPedidosDeAntesDeLasTablasSiguenConSuBaseMasKm() {
        CalculoPrecioDeliveryService service = servicio(metros("1000"));
        DatosEntrega viejo = new DatosEntrega();
        viejo.setTarifaBaseAplicada(new BigDecimal("8.00"));
        viejo.setPrecioKmAplicado(new BigDecimal("2.00"));

        assertInstanceOf(TarifaDelivery.class, service.tarifaDe(viejo));
        assertEquals(new BigDecimal("10.00"),
                service.fijarPrecioCompra(punto(1, 2), punto(3, 4), service.tarifaDe(viejo)).precioServicio());
        assertEquals("8 Bs + 2 Bs por km", CalculoPrecioDeliveryService.textoTarifaGuardada(viejo));
    }

    @Test
    void sinCopiaSeUsaLaTablaVigenteDeSuTipo() {
        CalculoPrecioDeliveryService service = servicio(metros("1000"));
        DatosEntrega paquete = new DatosEntrega();
        paquete.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        DatosEntrega compra = new DatosEntrega();
        compra.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);

        assertEquals(PAQUETE, service.tarifaDe(paquete));
        assertEquals(DELIVERY, service.tarifaDe(compra));
        assertEquals(null, CalculoPrecioDeliveryService.textoTarifaGuardada(compra));
    }

    @Test
    void unaCopiaIlegibleNoRompeElPedido() {
        CalculoPrecioDeliveryService service = servicio(metros("1000"));
        DatosEntrega datos = new DatosEntrega();
        datos.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        datos.setTarifaAplicadaJson("{roto");

        assertEquals(PAQUETE, service.tarifaDe(datos));
    }

    @Test
    void textoDeLaTabla() {
        assertEquals("8 Bs hasta 1 km, +2 Bs cada 1 km", CalculoPrecioDeliveryService.textoDe(DELIVERY));
        assertEquals("8 Bs hasta 5 km", CalculoPrecioDeliveryService.textoDe(
                new ParametrosPrecio(new BigDecimal("8.00"), new BigDecimal("5"), List.of(), 0, null)));
    }

    private static ParametrosPrecio tabla(String base, String kmBase, String kmTramo, String costoTramo) {
        return new ParametrosPrecio(new BigDecimal(base).setScale(2), new BigDecimal(kmBase),
                List.of(new ParametrosPrecio.Tramo(1, new BigDecimal(kmTramo), new BigDecimal(costoTramo).setScale(2), 1)),
                0, null);
    }

    private static ClienteRutas metros(String distancia) {
        return (origen, destino) -> new RutaResponse(new BigDecimal(distancia), 300);
    }

    private static ParametrosPrecioService tablas() {
        ParametrosPrecioService tablas = mock(ParametrosPrecioService.class);
        when(tablas.actuales(ServicioPrecio.DELIVERY)).thenReturn(DELIVERY);
        when(tablas.actuales(ServicioPrecio.PAQUETE)).thenReturn(PAQUETE);
        return tablas;
    }

    private static CalculoPrecioDeliveryService servicio(ClienteRutas rutas) {
        return new CalculoPrecioDeliveryService(rutas, tablas());
    }

    private Point punto(double x, double y) {
        return GEOMETRIA.createPoint(new Coordinate(x, y));
    }
}
