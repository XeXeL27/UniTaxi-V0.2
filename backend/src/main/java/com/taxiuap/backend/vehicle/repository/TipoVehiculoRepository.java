package com.taxiuap.backend.vehicle.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.vehicle.entity.TipoVehiculo;

/** Repositorio del catalogo de tipos de vehiculo. */
public interface TipoVehiculoRepository extends JpaRepository<TipoVehiculo, Integer> {

    Optional<TipoVehiculo> findByCodigo(String codigo);
}
