package com.taxiuap.backend.communication.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.communication.entity.Mensaje;

/** Repositorio de mensajes de chat. */
public interface MensajeRepository extends JpaRepository<Mensaje, Long> {

    List<Mensaje> findByViajeIdOrderByFechaAsc(Long idViaje);

    long countByViajeIdAndLeidoFalse(Long idViaje);
}
