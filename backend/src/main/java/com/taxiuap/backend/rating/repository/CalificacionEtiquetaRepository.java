package com.taxiuap.backend.rating.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.rating.entity.CalificacionEtiqueta;

/** Repositorio de la relacion entre calificaciones y etiquetas. */
public interface CalificacionEtiquetaRepository extends JpaRepository<CalificacionEtiqueta, Long> {

    List<CalificacionEtiqueta> findByCalificacionId(Long idCalificacion);
}
