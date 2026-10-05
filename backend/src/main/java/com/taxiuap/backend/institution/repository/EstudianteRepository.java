package com.taxiuap.backend.institution.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.institution.entity.Estudiante;

/** Acceso a datos de estudiante. */
public interface EstudianteRepository extends JpaRepository<Estudiante, Long> {

    Optional<Estudiante> findByPersonaId(Long idPersona);

    /** Estudiantes de una institucion con ese codigo (el RU en la UAP). */
    List<Estudiante> findByCodigoEstudianteAndInstitucionId(String codigoEstudiante, Long idInstitucion);
}
