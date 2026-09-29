package com.taxiuap.backend.trip.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.trip.entity.OfertaViaje;
import com.taxiuap.backend.trip.enums.SituacionOferta;

/** Repositorio de ofertas de viaje. */
public interface OfertaViajeRepository extends JpaRepository<OfertaViaje, Long> {

    List<OfertaViaje> findBySolicitudId(Long idSolicitud);

    List<OfertaViaje> findByConductorId(Long idConductor);

    List<OfertaViaje> findBySolicitudIdAndSituacionOferta(Long idSolicitud, SituacionOferta situacionOferta);

    boolean existsBySolicitudIdAndConductorId(Long idSolicitud, Long idConductor);

    boolean existsBySolicitudIdAndConductorIdAndSituacionOferta(
            Long idSolicitud, Long idConductor, SituacionOferta situacionOferta);
}
