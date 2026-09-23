package com.taxiuap.backend.location.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.location.entity.DireccionGuardada;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Repositorio de direcciones guardadas por los pasajeros. */
public interface DireccionGuardadaRepository extends JpaRepository<DireccionGuardada, Long> {

    List<DireccionGuardada> findByPasajeroIdAndEstadoDireccionGuardada(Long idPasajero, EstadoRegistro estadoDireccionGuardada);
}
