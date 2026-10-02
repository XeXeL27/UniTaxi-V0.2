package com.taxiuap.backend.trip.repository;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.dao.DataIntegrityViolationException;

import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.enums.TipoEnvio;

@SpringBootTest
@Transactional
class DatosEntregaPersistenciaTest {

    @Autowired private DatosEntregaRepository datosEntregaRepository;
    @Autowired private SolicitudViajeRepository solicitudViajeRepository;

    @Test
    void persisteLaRelacionUnoAUnoYRecuperaElMapeo() {
        SolicitudViaje solicitud = solicitudViajeRepository.findAll().stream().findFirst()
                .orElseThrow(() -> new AssertionError("El seed debe crear una solicitud de prueba"));

        DatosEntrega datos = new DatosEntrega();
        datos.setSolicitud(solicitud);
        datos.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        datos.setDescripcion("Medicamento de prueba");
        datos.setCostoProductoEstimado(new BigDecimal("25.00"));
        datos = datosEntregaRepository.saveAndFlush(datos);

        DatosEntrega recuperado = datosEntregaRepository.findBySolicitudId(solicitud.getId()).orElseThrow();
        assertNotNull(datos.getId());
        assertEquals(datos.getId(), recuperado.getId());
        assertEquals(solicitud.getId(), recuperado.getSolicitud().getId());
        assertEquals(TipoEnvio.COMPRA_Y_ENTREGA, recuperado.getTipoEnvio());

        DatosEntrega duplicado = new DatosEntrega();
        duplicado.setSolicitud(solicitud);
        duplicado.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        duplicado.setDescripcion("Duplicado");
        duplicado.setCostoProductoEstimado(new BigDecimal("10.00"));
        assertThrows(DataIntegrityViolationException.class,
                () -> datosEntregaRepository.saveAndFlush(duplicado));
    }
}
