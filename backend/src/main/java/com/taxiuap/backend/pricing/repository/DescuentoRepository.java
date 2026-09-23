package com.taxiuap.backend.pricing.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.pricing.entity.Descuento;

/** Repositorio de cupones y promociones de descuento. */
public interface DescuentoRepository extends JpaRepository<Descuento, Long> {

    Optional<Descuento> findByCodigo(String codigo);
}
