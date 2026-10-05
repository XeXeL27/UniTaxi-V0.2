package com.taxiuap.backend.trip.entity;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;

import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;

/**
 * Invariantes que el servidor no puede dejar pasar: una compra no llega a estar en manos del
 * repartidor sin confirmacion del cliente ni con el punto de compra real, y nada se entrega sin que
 * el repartidor confirme el pago.
 */
class DatosEntregaTransicionTest {

    @Test
    void unaCompraEnManoExigeConfirmacionDelCliente() {
        DatosEntrega datos = compra();
        datos.setEstadoEntrega(EstadoEntrega.EN_MANO);
        datos.setPuntoCompra(null);
        datos.setCostoProductoReal(new BigDecimal("25.00"));

        assertFalse(datos.isCompraConfirmadaParaTenerElPedido());

        datos.setCompraConfirmadaPorCliente(true);
        assertTrue(datos.isCompraConfirmadaParaTenerElPedido());
    }

    @Test
    void unaCompraEnManoExigePuntoDeCompraYCostoReal() {
        DatosEntrega datos = compra();
        datos.setEstadoEntrega(EstadoEntrega.EN_MANO);
        datos.setCompraConfirmadaPorCliente(true);

        assertFalse(datos.isPuntoDeCompraRegistrado());
        assertFalse(datos.isCostoRealRegistradoAntesDeEntregar());

        datos.setPuntoCompra(punto());
        assertTrue(datos.isPuntoDeCompraRegistrado());
        assertFalse(datos.isCostoRealRegistradoAntesDeEntregar());

        datos.setCostoProductoReal(new BigDecimal("25.00"));
        assertTrue(datos.isCostoRealRegistradoAntesDeEntregar());
    }

    @Test
    void noSePuedeEntregarSinPagoConfirmado() {
        DatosEntrega datos = compra();
        datos.setEstadoEntrega(EstadoEntrega.ENTREGADO);
        datos.setCompraConfirmadaPorCliente(true);
        datos.setPuntoCompra(punto());
        datos.setCostoProductoReal(new BigDecimal("25.00"));

        assertFalse(datos.isPagoConfirmadoParaEntregar());

        datos.setPagoConfirmado(true);
        assertTrue(datos.isPagoConfirmadoParaEntregar());
    }

    @Test
    void unaEncomiendaNoExigeConfirmacionDeCompra() {
        DatosEntrega datos = encomienda();
        datos.setEstadoEntrega(EstadoEntrega.ENTREGADO);

        assertTrue(datos.isCompraConfirmadaParaTenerElPedido());
        assertTrue(datos.isPuntoDeCompraRegistrado());
        assertTrue(datos.isCostoRealRegistradoAntesDeEntregar());
    }

    @Test
    void unaCompraSinEntregarConservaLoQueSeCompro() {
        DatosEntrega datos = compra();
        datos.setEstadoEntrega(EstadoEntrega.NO_ENTREGADO);
        datos.setCompraConfirmadaPorCliente(true);
        datos.setPuntoCompra(punto());
        datos.setCostoProductoReal(new BigDecimal("25.00"));
        datos.setFotoFallaUrl("personas/1/entrega/falla.jpg");
        datos.setMotivoFalla("El receptor no estaba");

        // El costo real ya pagado se conserva para que el admin resuelva el incidente.
        assertTrue(datos.isTieneEvidenciaDeFalla());
        assertTrue(datos.isCostoRealRegistradoAntesDeEntregar());
        assertTrue(datos.isPuntoDeCompraRegistrado());
    }

    private DatosEntrega compra() {
        DatosEntrega datos = new DatosEntrega();
        datos.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        datos.setDescripcion("Medicamento");
        datos.setCostoProductoEstimado(new BigDecimal("25.00"));
        return datos;
    }

    private DatosEntrega encomienda() {
        DatosEntrega datos = new DatosEntrega();
        datos.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        datos.setDescripcion("Documentos");
        datos.setCostoProductoEstimado(BigDecimal.ZERO);
        datos.setCodigoRecogida("123456");
        datos.setCodigoEntrega("654321");
        datos.setAceptaPoliticaArticulos(true);
        return datos;
    }

    private org.locationtech.jts.geom.Point punto() {
        return new org.locationtech.jts.geom.GeometryFactory(new org.locationtech.jts.geom.PrecisionModel(), 4326)
                .createPoint(new org.locationtech.jts.geom.Coordinate(-68.75, -11.02));
    }
}