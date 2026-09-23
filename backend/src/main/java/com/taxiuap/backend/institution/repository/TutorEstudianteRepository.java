package com.taxiuap.backend.institution.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.institution.entity.TutorEstudiante;

/** Acceso a datos de tutor de estudiante. */
public interface TutorEstudianteRepository extends JpaRepository<TutorEstudiante, Long> {

    List<TutorEstudiante> findByEstudianteId(Long idEstudiante);
}
