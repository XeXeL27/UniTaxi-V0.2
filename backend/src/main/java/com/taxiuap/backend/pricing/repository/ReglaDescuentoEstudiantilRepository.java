package com.taxiuap.backend.pricing.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.pricing.entity.ReglaDescuentoEstudiantil;

/** Repositorio de reglas de descuento estudiantil. */
public interface ReglaDescuentoEstudiantilRepository extends JpaRepository<ReglaDescuentoEstudiantil, Long> {
}
