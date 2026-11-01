package com.taxiuap.backend.trip.dto;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigDecimal;

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
}
