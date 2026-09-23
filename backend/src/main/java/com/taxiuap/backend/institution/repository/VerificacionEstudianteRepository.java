package com.taxiuap.backend.institution.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.institution.entity.VerificacionEstudiante;

/** Acceso a datos de verificacion de estudiante. */
public interface VerificacionEstudianteRepository extends JpaRepository<VerificacionEstudiante, Long> {

    List<VerificacionEstudiante> findByMatriculaId(Long idMatricula);
}
