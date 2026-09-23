package com.taxiuap.backend.identity.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Acceso a datos de conductor. */
public interface ConductorRepository extends JpaRepository<Conductor, Long> {

    Optional<Conductor> findByUsuarioId(Long idUsuario);

    List<Conductor> findByEstadoConductorOrderByIdAsc(EstadoRegistro estado);
}
