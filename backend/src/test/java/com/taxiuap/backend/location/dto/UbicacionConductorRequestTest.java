package com.taxiuap.backend.location.dto;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;

import com.taxiuap.backend.location.enums.Disponibilidad;
import com.taxiuap.backend.shared.exception.NegocioException;

class UbicacionConductorRequestTest {

    private static BigDecimal d(String valor) {
        return new BigDecimal(valor);
    }

    @Test
    void aceptaPosicionValida() {
        UbicacionConductorRequest request = new UbicacionConductorRequest(
                d("-11.0183"), d("-68.7551"), d("92.5"), d("24.0"), Disponibilidad.DISPONIBLE);
        assertEquals(d("-11.0183"), request.latitud());
        assertEquals(Disponibilidad.DISPONIBLE, request.disponibilidad());
    }

    @Test
    void aceptaPosicionSinRumboNiVelocidad() {
        assertDoesNotThrow(() -> new UbicacionConductorRequest(
                d("-11.0183"), d("-68.7551"), null, null, null));
    }

    @Test
    void rechazaCoordenadasAusentes() {
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(null, d("-68.7551"), null, null, null));
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("-11.0183"), null, null, null, null));
    }

    @Test
    void rechazaLatitudFueraDeRango() {
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("-90.1"), d("-68.7551"), null, null, null));
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("90.1"), d("-68.7551"), null, null, null));
    }

    @Test
    void rechazaLongitudFueraDeRango() {
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("-11.0183"), d("-180.1"), null, null, null));
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("-11.0183"), d("180.1"), null, null, null));
    }

    @Test
    void rechazaRumboFueraDeRango() {
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("-11.0183"), d("-68.7551"), d("360.1"), null, null));
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("-11.0183"), d("-68.7551"), d("-0.1"), null, null));
    }

    @Test
    void rechazaVelocidadNegativa() {
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("-11.0183"), d("-68.7551"), null, d("-1.0"), null));
    }
}
