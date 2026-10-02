package com.taxiuap.backend.trip.dto;

import static org.junit.jupiter.api.Assertions.assertFalse;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;

import com.taxiuap.backend.trip.enums.TipoEnvio;

import jakarta.validation.Validation;

class DatosEntregaRequestTest {

    @Test
    void compraNoAceptaCostoEstimadoCero() {
        DatosEntregaRequest request = new DatosEntregaRequest(
                TipoEnvio.COMPRA_Y_ENTREGA, "Medicamento", BigDecimal.ZERO,
                null, null, null, null, null, null);

        assertFalse(Validation.buildDefaultValidatorFactory().getValidator().validate(request).isEmpty());
    }
}
