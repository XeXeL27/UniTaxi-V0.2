package com.taxiuap.backend.shared.exception;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;

import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.transaction.TransactionSystemException;

import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.enums.TipoEnvio;

import jakarta.validation.ConstraintViolationException;
import jakarta.validation.Validation;

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

    /** Una regla de la entidad que falla al guardar responde 422 con el motivo, no "Error interno". */
    @Test
    void unaReglaDeEntidadRespondeElMotivoCon422() throws Exception {
        DatosEntrega paquete = new DatosEntrega();
        paquete.setSolicitud(new SolicitudViaje());
        paquete.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        paquete.setDescripcion("Documentos");
        paquete.setCodigoRecogida("123456");
        paquete.setCodigoEntrega("654321");
        var violaciones = Validation.buildDefaultValidatorFactory().getValidator().validate(paquete);
        ConstraintViolationException violacion = new ConstraintViolationException(violaciones);
        MockHttpServletRequest peticion = new MockHttpServletRequest("POST", "/api/pasajero/solicitudes");
        ManejadorGlobalExcepciones manejador = new ManejadorGlobalExcepciones();

        ResponseEntity<ApiResponse<Void>> directa = manejador.reglaDeEntidad(violacion, peticion);
        assertEquals(422, directa.getStatusCode().value());
        assertTrue(directa.getBody().getMensaje().contains("politica de articulos"));

        // Al confirmar la transaccion llega envuelta: el manejador general la reconoce igual.
        Exception envuelta = new TransactionSystemException("Could not commit", violacion);
        assertSame(violacion, ManejadorGlobalExcepciones.violacionDeEntidad(envuelta));
        assertEquals(422, manejador.fallo(envuelta, peticion).getStatusCode().value());

        assertNull(ManejadorGlobalExcepciones.violacionDeEntidad(new IllegalStateException("otra falla")));
        assertEquals(500, manejador.fallo(new IllegalStateException("otra falla"), peticion).getStatusCode().value());
    }
}
