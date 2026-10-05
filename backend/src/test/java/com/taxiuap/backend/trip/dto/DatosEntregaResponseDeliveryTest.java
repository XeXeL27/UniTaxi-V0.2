package com.taxiuap.backend.trip.dto;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;

import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;

/**
 * El repartidor necesita ver la propuesta de compra, el punto del comercio y el total a cobrar, pero
 * nunca los codigos: se los dictan por pantalla. Esta prueba fija esa frontera y los nombres con los
 * que la app los lee.
 */
class DatosEntregaResponseDeliveryTest {

    private static final GeometryFactory GEOMETRIA = new GeometryFactory(new PrecisionModel(), 4326);

    @Test
    void elRepartidorNuncaRecibeLosCodigos() {
        DatosEntregaResponse paraConductor = DatosEntregaResponse.desde(datos(), false);

        assertNull(paraConductor.codigoRecogida());
        assertNull(paraConductor.codigoEntrega());
    }

    @Test
    void elClienteSiRecibeLosCodigos() {
        DatosEntregaResponse paraPasajero = DatosEntregaResponse.desde(datos(), true);

        assertEquals("123456", paraPasajero.codigoRecogida());
        assertEquals("654321", paraPasajero.codigoEntrega());
    }

    @Test
    void elRepartidorVeElComercioYElTotalACobrar() {
        DatosEntregaResponse paraConductor = DatosEntregaResponse.desde(datos(), false);

        assertEquals("Farmacia Central", paraConductor.detalleCompraPropuesto());
        assertEquals(new BigDecimal("25.00"), paraConductor.costoProductoConfirmado());
        assertEquals(true, paraConductor.compraConfirmadaPorCliente());
        assertEquals(new BigDecimal("34.80"), paraConductor.montoPagoRecibido());
        assertEquals(true, paraConductor.pagoConfirmado());
        assertEquals(EstadoEntrega.EN_MANO, paraConductor.estadoEntrega());
    }

    @Test
    void elComercioSeExponeComoTextoParaPoderDibujarloEnElMapa() {
        DatosEntregaResponse paraConductor = DatosEntregaResponse.desde(datos(), false);

        assertEquals("POINT (-68.745 -11.025)", paraConductor.puntoCompraWkt());
        assertEquals("POINT (-68.74 -11.03)", paraConductor.puntoCompraPropuestoWkt());
    }

    private DatosEntrega datos() {
        DatosEntrega datos = new DatosEntrega();
        datos.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        datos.setDescripcion("Medicamento");
        datos.setCostoProductoEstimado(new BigDecimal("25.00"));
        datos.setCostoProductoReal(new BigDecimal("25.00"));
        datos.setCostoProductoConfirmado(new BigDecimal("25.00"));
        datos.setCompraConfirmadaPorCliente(true);
        datos.setPagoConfirmado(true);
        datos.setMontoPagoRecibido(new BigDecimal("34.80"));
        datos.setDetalleCompraPropuesto("Farmacia Central");
        datos.setCodigoRecogida("123456");
        datos.setCodigoEntrega("654321");
        datos.setPuntoCompra(punto(-68.745, -11.025));
        datos.setPuntoCompraPropuesto(punto(-68.74, -11.03));
        datos.setEstadoEntrega(EstadoEntrega.EN_MANO);
        return datos;
    }

    private Point punto(double longitud, double latitud) {
        return GEOMETRIA.createPoint(new Coordinate(longitud, latitud));
    }
}