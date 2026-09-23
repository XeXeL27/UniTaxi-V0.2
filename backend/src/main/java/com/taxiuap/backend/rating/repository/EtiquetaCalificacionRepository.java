package com.taxiuap.backend.rating.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.rating.entity.EtiquetaCalificacion;
import com.taxiuap.backend.rating.enums.AplicaA;

/** Repositorio de etiquetas de calificacion. */
public interface EtiquetaCalificacionRepository extends JpaRepository<EtiquetaCalificacion, Integer> {

    List<EtiquetaCalificacion> findByAplicaA(AplicaA aplicaA);
}
