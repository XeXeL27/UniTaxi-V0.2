package com.taxiuap.backend.rating.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.rating.entity.Calificacion;

/** Repositorio de calificaciones. */
public interface CalificacionRepository extends JpaRepository<Calificacion, Long> {

    List<Calificacion> findByViajeId(Long idViaje);

    List<Calificacion> findByUsuarioReceptorId(Long idUsuarioReceptor);

    boolean existsByViajeIdAndUsuarioEmisorId(Long idViaje, Long idUsuarioEmisor);
}
