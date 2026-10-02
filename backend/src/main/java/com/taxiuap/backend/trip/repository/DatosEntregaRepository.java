package com.taxiuap.backend.trip.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.trip.entity.DatosEntrega;

/** Repositorio de los datos adicionales de solicitudes DELIVERY. */
public interface DatosEntregaRepository extends JpaRepository<DatosEntrega, Long> {

    Optional<DatosEntrega> findBySolicitudId(Long idSolicitud);
}
