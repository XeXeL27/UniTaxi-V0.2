package com.taxiuap.backend.location.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.taxiuap.backend.location.entity.UbicacionConductor;

/** Repositorio de la ultima ubicacion conocida de cada conductor. */
public interface UbicacionConductorRepository extends JpaRepository<UbicacionConductor, Long> {

    Optional<UbicacionConductor> findByConductorId(Long idConductor);

    /** Ubicaciones de varios conductores en una sola consulta, para pintar el mapa de flota. */
    List<UbicacionConductor> findByConductorIdIn(List<Long> idConductores);

    /**
     * Distancia en metros en linea recta entre la ubicacion del conductor y un punto dado.
     * Usa ST_Distance sobre geography con el esferoide (use_spheroid=false) para obtener metros.
     * Devuelve null si el conductor no tiene ubicacion registrada.
     */
    @Query(value = "select ST_Distance(uc.ubicacion, ST_SetSRID(ST_MakePoint(:longitud, :latitud), 4326)::geography, false) "
            + "from ubicacion_conductor uc where uc.id_conductor = :idConductor and uc.estado_ubic_cond = 'A'",
            nativeQuery = true)
    Double distanciaMetrosHasta(@Param("idConductor") Long idConductor,
            @Param("latitud") double latitud,
            @Param("longitud") double longitud);
}
