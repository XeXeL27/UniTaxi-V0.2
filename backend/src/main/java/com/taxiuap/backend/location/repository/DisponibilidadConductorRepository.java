package com.taxiuap.backend.location.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.location.entity.DisponibilidadConductor;
import com.taxiuap.backend.location.enums.Disponibilidad;

/** Repositorio del historial de disponibilidad de los conductores. */
public interface DisponibilidadConductorRepository extends JpaRepository<DisponibilidadConductor, Long> {

    Optional<DisponibilidadConductor> findFirstByConductorIdOrderByDesdeDesc(Long idConductor);

    List<DisponibilidadConductor> findByDisponibilidad(Disponibilidad disponibilidad);
}
