package com.taxiuap.backend.pricing.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.pricing.entity.TramoPrecio;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

public interface TramoPrecioRepository extends JpaRepository<TramoPrecio, Integer> {

    List<TramoPrecio> findByEstadoTramoOrderByOrdenAscIdAsc(EstadoRegistro estadoTramo);
}
