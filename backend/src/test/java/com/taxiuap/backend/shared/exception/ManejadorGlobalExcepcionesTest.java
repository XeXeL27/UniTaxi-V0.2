package com.taxiuap.backend.shared.exception;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;

import org.junit.jupiter.api.Test;

/** El telefono que corta la conexion no es una falla del servidor: no debe quedar como ERROR en el log. */
class ManejadorGlobalExcepcionesTest {

    @Test
    void reconoceElBrokenPipeAunqueVengaEnvuelto() {
        Exception e = new IllegalStateException("ServletResponse failed to flushBuffer",
                new IOException("java.io.IOException: Broken pipe", new IOException("Broken pipe")));

        assertTrue(ManejadorGlobalExcepciones.clienteDesconecto(e));
    }

    @Test
    void reconoceLaConexionReiniciada() {
        assertTrue(ManejadorGlobalExcepciones.clienteDesconecto(new IOException("Connection reset by peer")));
    }

    @Test
    void unaFallaRealSigueSiendoFalla() {
        assertFalse(ManejadorGlobalExcepciones.clienteDesconecto(new IllegalStateException("columna inexistente")));
        assertFalse(ManejadorGlobalExcepciones.clienteDesconecto(new IOException("Disco lleno")));
    }
}
