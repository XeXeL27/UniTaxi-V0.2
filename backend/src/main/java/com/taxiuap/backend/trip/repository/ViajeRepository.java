package com.taxiuap.backend.trip.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.SituacionViaje;

/** Repositorio de viajes. */
public interface ViajeRepository extends JpaRepository<Viaje, Long> {

    List<Viaje> findByPasajeroIdOrderByFechaInicioDesc(Long idPasajero);

    List<Viaje> findByConductorIdOrderByFechaInicioDesc(Long idConductor);

    Optional<Viaje> findBySolicitudId(Long idSolicitud);

    List<Viaje> findByConductorIdAndSituacionViaje(Long idConductor, SituacionViaje situacionViaje);

    /** Viaje activo (no finalizado ni cancelado) del pasajero, usado para saber si tiene uno en curso. */
    Optional<Viaje> findFirstByPasajeroIdAndSituacionViajeNotIn(Long idPasajero, List<SituacionViaje> situaciones);

    /** Viaje activo (no finalizado ni cancelado) del conductor, usado para saber si tiene uno en curso. */
    Optional<Viaje> findFirstByConductorIdAndSituacionViajeNotIn(Long idConductor, List<SituacionViaje> situaciones);

    /**
     * Cuenta los viajes de un estudiante con descuento estudiantil aplicado en un rango de
     * fechas, usado por el calculo de precio para respetar viajes_maximos_dia de la regla 3.
     */
    @Query("select count(v) from Viaje v where v.estudiante.id = :idEstudiante "
            + "and v.montoDescuento > 0 and v.creadoEn >= :desde and v.creadoEn < :hasta")
    long contarConDescuentoEnRango(
            @Param("idEstudiante") Long idEstudiante,
            @Param("desde") LocalDateTime desde,
            @Param("hasta") LocalDateTime hasta);
}
