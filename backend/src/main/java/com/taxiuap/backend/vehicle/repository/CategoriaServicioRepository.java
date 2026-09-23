package com.taxiuap.backend.vehicle.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;

/** Repositorio del catalogo de categorias de servicio. */
public interface CategoriaServicioRepository extends JpaRepository<CategoriaServicio, Integer> {

    List<CategoriaServicio> findByTipoVehiculoId(Integer idTipoVehiculo);

    List<CategoriaServicio> findByTipoVehiculoIdAndEstadoCategoriaServicio(Integer idTipoVehiculo, EstadoRegistro estado);
}
