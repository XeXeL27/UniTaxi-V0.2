package com.taxiuap.backend.communication.repository;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.time.LocalDateTime;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.communication.entity.Reporte;
import com.taxiuap.backend.communication.enums.SituacionReporte;
import com.taxiuap.backend.communication.enums.TipoResolucionReporte;

/** Verifica con el repositorio JPA real que la resolución queda persistida, incluida su identidad. */
@SpringBootTest
@Transactional
class ReportePersistenciaTest {

    @Autowired private ReporteRepository reporteRepository;

    @Test
    void persisteFechaResolucionTipoYAdminPorId() {
        Reporte reporte = reporteRepository.findAll().stream().findFirst()
                .orElseThrow(() -> new IllegalStateException("Se necesita un reporte DELIVERY de prueba"));
        Long idAdmin = reporte.getUsuarioReporta().getId();
        LocalDateTime fecha = LocalDateTime.now().withNano(0);
        reporte.setTipoResolucion(TipoResolucionReporte.OTRO);
        reporte.setObservacionAdmin("Gestion verificada");
        reporte.setFechaResolucion(fecha);
        reporte.setUsuarioAdminResolvio(reporte.getUsuarioReporta());
        reporte.setSituacionReporte(SituacionReporte.RESUELTO);
        reporteRepository.saveAndFlush(reporte);

        Reporte recuperado = reporteRepository.findById(reporte.getId()).orElseThrow();
        assertNotNull(recuperado.getFechaResolucion());
        assertEquals(fecha, recuperado.getFechaResolucion());
        assertEquals(idAdmin, recuperado.getUsuarioAdminResolvio().getId());
        assertEquals(SituacionReporte.RESUELTO, recuperado.getSituacionReporte());
    }
}
