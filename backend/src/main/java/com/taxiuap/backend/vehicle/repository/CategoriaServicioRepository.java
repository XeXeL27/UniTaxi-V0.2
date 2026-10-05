package com.taxiuap.backend.vehicle.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;

/** Repositorio del catalogo de categorias de servicio. */
public interface CategoriaServicioRepository extends JpaRepository<CategoriaServicio, Integer> {

    List<CategoriaServicio> findByTipoVehiculoId(Integer idTipoVehiculo);

    List<CategoriaServicio> findByTipoVehiculoIdAndEstadoCategoriaServicio(Integer idTipoVehiculo, EstadoRegistro estado);

    /** Categoria por id exigiendo que siga activa: una categoria eliminada no se puede asignar. */
    Optional<CategoriaServicio> findByIdAndEstadoCategoriaServicio(Integer id, EstadoRegistro estado);

    /**
     * Categoria estandar de un tipo de vehiculo: la activa de menor id cuyo nombre no sea
     * [nombreExcluido]. El orden y el filtro son explicitos a proposito: en MOTO hay varias
     * categorias activas (DELIVERY entre ellas) y sin ORDER BY el registro se llevaria cualquiera
     * segun el plan de ejecucion de la base.
     */
    Optional<CategoriaServicio> findFirstByTipoVehiculoIdAndEstadoCategoriaServicioAndNombreNotIgnoreCaseOrderByIdAsc(
            Integer idTipoVehiculo, EstadoRegistro estado, String nombreExcluido);
}
