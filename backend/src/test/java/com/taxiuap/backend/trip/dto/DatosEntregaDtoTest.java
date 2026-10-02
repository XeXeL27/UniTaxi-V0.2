package com.taxiuap.backend.trip.dto;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;

import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;

import tools.jackson.databind.ObjectMapper;

class DatosEntregaDtoTest {

    @Test
    void serializaLosCamposDeEntregaConNombresDeApi() throws Exception {
        DatosEntregaResponse response = new DatosEntregaResponse(
                TipoEnvio.COMPRA_Y_ENTREGA,
                "Medicamento",
                new BigDecimal("25.00"),
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                EstadoEntrega.PENDIENTE_RECOGIDA);

        String json = new ObjectMapper().writeValueAsString(response);
        var node = new ObjectMapper().readTree(json);

        assertEquals("COMPRA_Y_ENTREGA", node.get("tipoEnvio").asText());
        assertEquals(25.00, node.get("costoProductoEstimado").asDouble());
        assertEquals("PENDIENTE_RECOGIDA", node.get("estadoEntrega").asText());
    }
}
