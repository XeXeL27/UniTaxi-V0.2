package com.taxiuap.backend.institution.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.institution.entity.Carrera;

/** Acceso a datos de carrera. */
public interface CarreraRepository extends JpaRepository<Carrera, Long> {

    List<Carrera> findByInstitucionId(Long idInstitucion);
}
