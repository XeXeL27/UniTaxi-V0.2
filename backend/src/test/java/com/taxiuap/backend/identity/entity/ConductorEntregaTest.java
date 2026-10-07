package com.taxiuap.backend.identity.entity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;

import jakarta.validation.Validation;

class ConductorEntregaTest {

    @Test
    void limiteDeAdelantoEsObligatorioYNoNegativo() {
        Conductor conductor = new Conductor();
        conductor.setLimiteAdelantoCompra(new BigDecimal("-0.01"));
        assertFalse(Validation.buildDefaultValidatorFactory().getValidator().validate(conductor).isEmpty());

        conductor.setLimiteAdelantoCompra(null);
        assertFalse(Validation.buildDefaultValidatorFactory().getValidator().validate(conductor).isEmpty());
    }

    @Test
    void normalizaElLimiteNuloDeConductoresAntiguosAntesDePersistir() {
        Conductor conductor = new Conductor();
        conductor.setLimiteAdelantoCompra(null);

        conductor.normalizarLimiteAdelantoCompra();

        assertEquals(BigDecimal.ZERO, conductor.getLimiteAdelantoCompra());
    }
}
