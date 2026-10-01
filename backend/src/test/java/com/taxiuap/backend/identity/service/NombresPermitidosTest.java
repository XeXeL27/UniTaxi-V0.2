package com.taxiuap.backend.identity.service;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

import org.junit.jupiter.api.Test;

/** Nombres inventados: ningun dato real de personas. */
class NombresPermitidosTest {

    @Test
    void aceptaNombresReales() {
        assertNull(NombresPermitidos.problema("JUAN CARLOS", "PEREZ MAMANI"));
        assertNull(NombresPermitidos.problema("MARÍA JOSÉ", "DE LA CRUZ QUISPE"));
        assertNull(NombresPermitidos.problema("ANA", "VERGARA CONCHA"));
        assertNull(NombresPermitidos.problema("ÑUFLO", "ÑUSTA Y CHOQUE"));
    }

    @Test
    void observaGroseriasYAlbures() {
        assertNotNull(NombresPermitidos.problema("EL VERGUDO", "PEREZ"));
        assertNotNull(NombresPermitidos.problema("ELVERGUDO", "PEREZ"));
        assertNotNull(NombresPermitidos.problema("JUAN", "C0JUD0"));
        assertNotNull(NombresPermitidos.problema("PUUUTA", "MADRE"));
        assertNotNull(NombresPermitidos.problema("PEDRO", "Pendejo"));
    }

    @Test
    void observaNombresQueNoParecenNombres() {
        assertNotNull(NombresPermitidos.problema("PRUEBA", "PRUEBA"));
        assertNotNull(NombresPermitidos.problema("JUAN2", "PEREZ"));
        assertNotNull(NombresPermitidos.problema("AAAA", "PEREZ"));
        assertNotNull(NombresPermitidos.problema("JUAN", "BCDFG"));
        assertNotNull(NombresPermitidos.problema("J", "PEREZ"));
        assertNotNull(NombresPermitidos.problema("", ""));
    }
}
