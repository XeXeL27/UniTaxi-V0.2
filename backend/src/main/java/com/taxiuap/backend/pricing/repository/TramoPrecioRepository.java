package com.taxiuap.backend.pricing.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import com.taxiuap.backend.pricing.entity.TramoPrecio;
import com.taxiuap.backend.pricing.enums.ServicioPrecio;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

public interface TramoPrecioRepository extends JpaRepository<TramoPrecio, Integer> {

    List<TramoPrecio> findByServicioAndEstadoTramoOrderByOrdenAscIdAsc(ServicioPrecio servicio,
            EstadoRegistro estadoTramo);

    long countByServicio(ServicioPrecio servicio);

    /** Los tramos de antes de separar los servicios (columna nueva vacia) son del moto taxi. */
    @Modifying
    @Query("update TramoPrecio t set t.servicio = com.taxiuap.backend.pricing.enums.ServicioPrecio.TAXI "
            + "where t.servicio is null")
    int asignarTaxiALosDeAntes();
}
