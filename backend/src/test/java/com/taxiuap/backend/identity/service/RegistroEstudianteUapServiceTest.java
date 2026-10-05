package com.taxiuap.backend.identity.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class RegistroEstudianteUapServiceTest {

    @Test
    void ocultaElCorreo() {
        assertEquals("ju***@correo.test", RegistroEstudianteUapService.ocultar("juan.prueba@correo.test"));
        assertEquals("a***@correo.test", RegistroEstudianteUapService.ocultar("a@correo.test"));
        assertNull(RegistroEstudianteUapService.ocultar(null));
    }

    @Test
    void laFotoDelSigseSoloSiNoTieneFoto() {
        byte[] foto = new byte[200];
        assertTrue(RegistroEstudianteUapService.usarFotoSigse(null, foto));
        assertTrue(RegistroEstudianteUapService.usarFotoSigse(" ", foto));
        assertFalse(RegistroEstudianteUapService.usarFotoSigse("personas/1_123/general/foto_perfil_pasajero.jpg", foto));
        assertFalse(RegistroEstudianteUapService.usarFotoSigse(null, null));
    }
}
