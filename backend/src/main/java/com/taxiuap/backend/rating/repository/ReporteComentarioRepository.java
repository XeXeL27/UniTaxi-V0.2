package com.taxiuap.backend.rating.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.rating.entity.ReporteComentario;
import com.taxiuap.backend.rating.enums.SituacionRevisionComentario;

/** Repositorio de reportes sobre comentarios de calificacion. */
public interface ReporteComentarioRepository extends JpaRepository<ReporteComentario, Long> {

    List<ReporteComentario> findBySituacionRevision(SituacionRevisionComentario situacionRevision);
}
