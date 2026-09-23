package com.taxiuap.backend.location.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.location.entity.Zona;

/** Repositorio de zonas geograficas de cobertura. */
public interface ZonaRepository extends JpaRepository<Zona, Integer> {
}
