package com.taxiuap.backend.institution.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.institution.entity.MatriculaEstudiante;
import com.taxiuap.backend.institution.enums.SituacionVerificacion;

/** Acceso a datos de matricula de estudiante. */
public interface MatriculaEstudianteRepository extends JpaRepository<MatriculaEstudiante, Long> {

    List<MatriculaEstudiante> findByEstudianteId(Long idEstudiante);

    List<MatriculaEstudiante> findBySituacionVerificacion(SituacionVerificacion situacionVerificacion);
}
