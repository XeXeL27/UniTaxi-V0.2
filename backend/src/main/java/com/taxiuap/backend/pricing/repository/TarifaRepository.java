package com.taxiuap.backend.pricing.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.pricing.entity.Tarifa;

/** Repositorio de tarifas por categoria de servicio y zona. */
public interface TarifaRepository extends JpaRepository<Tarifa, Long> {

    List<Tarifa> findByCategoriaServicioIdAndZonaId(Integer idCategoriaServicio, Integer idZona);

    /** Tarifas de una categoria de servicio sin importar la zona, usada como respaldo del calculo de precio. */
    List<Tarifa> findByCategoriaServicioId(Integer idCategoriaServicio);
}
