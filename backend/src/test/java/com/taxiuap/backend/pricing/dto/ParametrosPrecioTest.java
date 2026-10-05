package com.taxiuap.backend.pricing.dto;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.math.BigDecimal;
import java.util.List;

import org.junit.jupiter.api.Test;

class ParametrosPrecioTest {

    private static ParametrosPrecio.Tramo tramo(String km, String costo) {
        return new ParametrosPrecio.Tramo(null, new BigDecimal(km), new BigDecimal(costo), null);
    }

    /** Base 5 km = 8 Bs; tramos +3 km +2 Bs y +4 km +3 Bs. */
    private final ParametrosPrecio parametros = new ParametrosPrecio(new BigDecimal("8.00"), new BigDecimal("5"),
            List.of(tramo("3", "2.00"), tramo("4", "3.00")), 2, null);

    private String precio(String km) {
        return parametros.precioPara(new BigDecimal(km)).toPlainString();
    }

    @Test
    void hastaLosKmBaseSeCobraElPrecioBase() {
        assertEquals("8.00", precio("0.4"));
        assertEquals("8.00", precio("5"));
    }

    @Test
    void cadaTramoSumaSusKmYSuCosto() {
        assertEquals("10.00", precio("5.01"));
        assertEquals("10.00", precio("8"));
        assertEquals("13.00", precio("8.2"));
        assertEquals("13.00", precio("12"));
    }

    @Test
    void despuesDelUltimoTramoSeRepiteElUltimo() {
        assertEquals("16.00", precio("12.5"));
        assertEquals("16.00", precio("16"));
        assertEquals("19.00", precio("16.1"));
    }

    @Test
    void sinTramosSoloElPrecioBase() {
        ParametrosPrecio soloBase = new ParametrosPrecio(new BigDecimal("8.00"), new BigDecimal("5"), List.of(), 0, null);
        assertEquals("8.00", soloBase.precioPara(new BigDecimal("20")).toPlainString());
        assertEquals("8.00", parametros.precioPara(null).toPlainString());
    }
}
