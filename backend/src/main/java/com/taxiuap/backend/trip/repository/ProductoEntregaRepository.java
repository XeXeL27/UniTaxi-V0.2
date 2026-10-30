package com.taxiuap.backend.trip.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.entity.ProductoEntrega;

public interface ProductoEntregaRepository extends JpaRepository<ProductoEntrega, Long> {

    List<ProductoEntrega> findByDatosEntregaIdAndEstadoProductoEntregaOrderByOrdenAscIdAsc(Long idDatosEntrega,
            EstadoRegistro estado);
}
