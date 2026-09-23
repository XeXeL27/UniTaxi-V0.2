package com.taxiuap.backend.communication.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.communication.entity.Reporte;
import com.taxiuap.backend.communication.enums.SituacionReporte;

/** Repositorio de reportes de incidentes. */
public interface ReporteRepository extends JpaRepository<Reporte, Long> {

    List<Reporte> findBySituacionReporte(SituacionReporte situacionReporte);

    List<Reporte> findByViajeId(Long idViaje);
}
