package com.taxiuap.backend.trip.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.trip.entity.PuntoRecorrido;

/** Repositorio de puntos de recorrido de un viaje. */
public interface PuntoRecorridoRepository extends JpaRepository<PuntoRecorrido, Long> {

    List<PuntoRecorrido> findByViajeIdOrderByRegistradoEnAsc(Long idViaje);
}
