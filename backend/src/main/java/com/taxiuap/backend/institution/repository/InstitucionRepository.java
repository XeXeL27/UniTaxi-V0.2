package com.taxiuap.backend.institution.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.institution.entity.Institucion;

/** Acceso a datos de institucion. */
public interface InstitucionRepository extends JpaRepository<Institucion, Long> {

    List<Institucion> findByTipoInstitucionId(Integer idTipoInstitucion);
}
