package com.taxiuap.backend.institution.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.institution.entity.TipoInstitucion;

/** Acceso a datos de tipo de institucion. */
public interface TipoInstitucionRepository extends JpaRepository<TipoInstitucion, Integer> {

    Optional<TipoInstitucion> findByCodigo(String codigo);
}
