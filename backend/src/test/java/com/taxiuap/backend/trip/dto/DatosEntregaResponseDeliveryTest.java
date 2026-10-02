package com.taxiuap.backend.trip.dto;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;

import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;

class DatosEntregaResponseDeliveryTest {

    @Test
    void noExponeCodigosAlConductor() {
        DatosEntregaResponse datos = new DatosEntregaResponse(
                TipoEnvio.ENCOMIENDA, "documentos", BigDecimal.ZERO, null,
                "Remitente", "70000000", "Receptor", "71111111",
                "123456", "654321", null, null, null, null, null, null,
                EstadoEntrega.PENDIENTE_RECOGIDA);

        DatosEntregaResponse paraConductor = datos.paraConductor();

        assertNull(paraConductor.codigoRecogida());
        assertNull(paraConductor.codigoEntrega());
        assertEquals(datos.descripcion(), paraConductor.descripcion());
        assertEquals(datos.estadoEntrega(), paraConductor.estadoEntrega());
    }
}
