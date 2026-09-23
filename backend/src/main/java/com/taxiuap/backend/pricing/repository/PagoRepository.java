package com.taxiuap.backend.pricing.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.pricing.entity.Pago;

/** Repositorio de pagos de viajes. */
public interface PagoRepository extends JpaRepository<Pago, Long> {

    Optional<Pago> findByViajeId(Long idViaje);
}
