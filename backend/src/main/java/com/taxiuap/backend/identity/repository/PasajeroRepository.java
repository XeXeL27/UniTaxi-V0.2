package com.taxiuap.backend.identity.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Acceso a datos de pasajero. */
public interface PasajeroRepository extends JpaRepository<Pasajero, Long> {

    Optional<Pasajero> findByUsuarioId(Long idUsuario);

    /**
     * Bloquea la fila del pasajero hasta que termine la transaccion: si pide dos veces a la vez
     * (doble toque) la segunda espera, ve la solicitud de la primera y se rechaza (regla 4).
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from Pasajero p where p.id = :id")
    Optional<Pasajero> bloquear(@Param("id") Long id);

    List<Pasajero> findByEstadoPasajeroOrderByIdAsc(EstadoRegistro estado);
}
