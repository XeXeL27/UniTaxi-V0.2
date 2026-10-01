package com.taxiuap.backend.identity.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Acceso a datos de conductor. */
public interface ConductorRepository extends JpaRepository<Conductor, Long> {

    Optional<Conductor> findByUsuarioId(Long idUsuario);

    /**
     * Bloquea la fila del conductor hasta que termine la transaccion (SELECT ... FOR UPDATE): si el
     * mismo conductor acepta dos solicitudes a la vez, la segunda espera y ve el viaje de la primera.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from Conductor c where c.id = :id")
    Optional<Conductor> bloquear(@Param("id") Long id);

    List<Conductor> findByEstadoConductorOrderByIdAsc(EstadoRegistro estado);

    /**
     * Conductores que pueden aparecer en el mapa de flota: los que pasaron la aprobacion y siguen
     * dados de alta. El orden por id es estable y no cambia entre llamadas, que es lo que quiere el
     * panel para no ver los marcadores saltando de lugar en cada recarga.
     */
    List<Conductor> findBySituacionAprobacionAndEstadoConductorOrderByIdAsc(
            SituacionAprobacion situacion, EstadoRegistro estado);
}
