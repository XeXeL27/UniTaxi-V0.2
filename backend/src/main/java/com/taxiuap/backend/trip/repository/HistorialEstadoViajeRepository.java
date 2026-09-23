package com.taxiuap.backend.trip.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.trip.entity.HistorialEstadoViaje;

/** Repositorio del historial de estados de un viaje. */
public interface HistorialEstadoViajeRepository extends JpaRepository<HistorialEstadoViaje, Long> {

    List<HistorialEstadoViaje> findByViajeIdOrderByFechaAsc(Long idViaje);
}
