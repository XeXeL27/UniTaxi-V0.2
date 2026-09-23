package com.taxiuap.backend.location.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.location.entity.UbicacionConductor;

/** Repositorio de la ultima ubicacion conocida de cada conductor. */
public interface UbicacionConductorRepository extends JpaRepository<UbicacionConductor, Long> {

    Optional<UbicacionConductor> findByConductorId(Long idConductor);
}
