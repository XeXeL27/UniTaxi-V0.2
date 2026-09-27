package com.taxiuap.backend.location.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.location.entity.DisponibilidadConductor;
import com.taxiuap.backend.location.enums.Disponibilidad;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Repositorio del historial de disponibilidad de los conductores. */
public interface DisponibilidadConductorRepository extends JpaRepository<DisponibilidadConductor, Long> {

    /**
     * Ultima disponibilidad vigente de un conductor.
     *
     * Filtra por estado porque el borrado es logico: sin este filtro un registro dado de baja
     * podria seguir apareciendo como el mas reciente y dejar la disponibilidad congelada.
     */
    Optional<DisponibilidadConductor> findFirstByConductorIdAndEstadoDisponibilidadConductorOrderByDesdeDesc(
            Long idConductor, EstadoRegistro estado);

    List<DisponibilidadConductor> findByDisponibilidad(Disponibilidad disponibilidad);

    /**
     * Historial de disponibilidad de varios conductores, del mas reciente al mas antiguo de cada
     * uno. Al recorrer la lista en ese orden, el primer registro que aparece de cada conductor es
     * su disponibilidad vigente, y se puede armar el mapa de toda la flota con una sola consulta.
     */
    List<DisponibilidadConductor> findByConductorIdInAndEstadoDisponibilidadConductorOrderByConductorIdAscDesdeDesc(
            List<Long> idConductores, EstadoRegistro estado);
}
