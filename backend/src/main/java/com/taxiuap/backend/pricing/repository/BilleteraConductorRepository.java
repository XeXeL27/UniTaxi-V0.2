package com.taxiuap.backend.pricing.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.pricing.entity.BilleteraConductor;

/** Repositorio de billeteras de conductor. */
public interface BilleteraConductorRepository extends JpaRepository<BilleteraConductor, Long> {

    Optional<BilleteraConductor> findByConductorId(Long idConductor);
}
