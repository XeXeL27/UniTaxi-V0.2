package com.taxiuap.backend.pricing.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.pricing.entity.Comision;

/** Repositorio de comisiones cobradas por viaje. */
public interface ComisionRepository extends JpaRepository<Comision, Long> {

    Optional<Comision> findByViajeId(Long idViaje);
}
