package com.taxiuap.backend.identity.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Acceso a datos de conductor. */
public interface ConductorRepository extends JpaRepository<Conductor, Long> {

    Optional<Conductor> findByUsuarioId(Long idUsuario);

    List<Conductor> findByEstadoConductorOrderByIdAsc(EstadoRegistro estado);

    /**
     * Conductores que pueden aparecer en el mapa de flota: los que pasaron la aprobacion y siguen
     * dados de alta. El orden por id es estable y no cambia entre llamadas, que es lo que quiere el
     * panel para no ver los marcadores saltando de lugar en cada recarga.
     */
    List<Conductor> findBySituacionAprobacionAndEstadoConductorOrderByIdAsc(
            SituacionAprobacion situacion, EstadoRegistro estado);
}
