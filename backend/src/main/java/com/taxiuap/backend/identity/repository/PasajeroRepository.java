package com.taxiuap.backend.identity.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Acceso a datos de pasajero. */
public interface PasajeroRepository extends JpaRepository<Pasajero, Long> {

    Optional<Pasajero> findByUsuarioId(Long idUsuario);

    List<Pasajero> findByEstadoPasajeroOrderByIdAsc(EstadoRegistro estado);
}
