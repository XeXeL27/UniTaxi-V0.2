package com.taxiuap.backend.trip.dto;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigDecimal;
import java.util.List;

import org.junit.jupiter.api.Test;

import com.taxiuap.backend.trip.enums.TipoEnvio;

import jakarta.validation.Validation;

class DatosEntregaRequestTest {

    @Test
    void unaCompraNoNecesitaCostoEstimado() {
        DatosEntregaRequest request = new DatosEntregaRequest(
                TipoEnvio.COMPRA_Y_ENTREGA, "Medicamento", null,
                null, null, null, null, null, null);

        assertTrue(Validation.buildDefaultValidatorFactory().getValidator().validate(request).isEmpty());
    }

    @Test
    void unPaqueteNoLlevaCostoDeProductos() {
        DatosEntregaRequest request = new DatosEntregaRequest(
                TipoEnvio.ENCOMIENDA, "Sobre", new BigDecimal("10.00"),
                null, null, null, null, null, true);

        assertFalse(Validation.buildDefaultValidatorFactory().getValidator().validate(request).isEmpty());
    }

    @Test
    void laCasillaDeLaMotoSoloSeExigeEnElPaquete() {
        var validador = Validation.buildDefaultValidatorFactory().getValidator();
        DatosEntregaRequest paqueteSinCasilla = new DatosEntregaRequest(
                TipoEnvio.ENCOMIENDA, "Documentos", null, null, null, null, null, null, false);
        DatosEntregaRequest paqueteSinDato = new DatosEntregaRequest(
                TipoEnvio.ENCOMIENDA, "Documentos", null, null, null, null, null, null, null);
        DatosEntregaRequest paqueteConCasilla = new DatosEntregaRequest(
                TipoEnvio.ENCOMIENDA, "Documentos", null, null, null, null, null, null, true);
        DatosEntregaRequest deliverySinCasilla = new DatosEntregaRequest(
                TipoEnvio.COMPRA_Y_ENTREGA, "2 x Pan", null, null, null, null, null, null, false,
                List.of(new ProductoSolicitadoRequest("Pan", 2, null)));

        assertTrue(validador.validate(paqueteSinCasilla).stream()
                .anyMatch(v -> v.getMessage().contains("cabe en una moto")));
        assertFalse(validador.validate(paqueteSinDato).isEmpty());
        assertTrue(validador.validate(paqueteConCasilla).isEmpty());
        assertTrue(validador.validate(deliverySinCasilla).isEmpty());
    }
}
