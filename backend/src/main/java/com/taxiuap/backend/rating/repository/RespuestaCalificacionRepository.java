package com.taxiuap.backend.rating.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.rating.entity.RespuestaCalificacion;

/** Repositorio de respuestas a calificaciones. */
public interface RespuestaCalificacionRepository extends JpaRepository<RespuestaCalificacion, Long> {

    Optional<RespuestaCalificacion> findByCalificacionId(Long idCalificacion);
}
