package com.taxiuap.backend.communication.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.communication.entity.Reporte;
import com.taxiuap.backend.communication.enums.SituacionReporte;

/** Repositorio de reportes de incidentes. */
public interface ReporteRepository extends JpaRepository<Reporte, Long> {

    List<Reporte> findBySituacionReporte(SituacionReporte situacionReporte);

    List<Reporte> findByViajeId(Long idViaje);

    /** Reportes de un motivo sobre los viajes de un pasajero (por ejemplo, cuantas veces no se presento). */
    long countByMotivoAndViajePasajeroId(String motivo, Long idPasajero);
}
