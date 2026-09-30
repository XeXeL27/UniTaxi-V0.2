package com.taxiuap.backend.trip.repository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.taxiuap.backend.shared.enums.EstadoRegistro;
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

    // ------------------------------------------------ historial de la app (viajes completados)

    @Query("""
            select v from Viaje v where v.pasajero.id = :id and v.situacionViaje = :situacion
            and v.estadoViaje = :estado and v.fechaFin >= :desde and v.fechaFin < :hasta
            order by v.fechaFin desc, v.id desc""")
    Page<Viaje> historialDePasajero(@Param("id") Long idPasajero, @Param("situacion") SituacionViaje situacion,
            @Param("estado") EstadoRegistro estado, @Param("desde") LocalDateTime desde,
            @Param("hasta") LocalDateTime hasta, Pageable pagina);

    @Query("""
            select v from Viaje v where v.conductor.id = :id and v.situacionViaje = :situacion
            and v.estadoViaje = :estado and v.fechaFin >= :desde and v.fechaFin < :hasta
            order by v.fechaFin desc, v.id desc""")
    Page<Viaje> historialDeConductor(@Param("id") Long idConductor, @Param("situacion") SituacionViaje situacion,
            @Param("estado") EstadoRegistro estado, @Param("desde") LocalDateTime desde,
            @Param("hasta") LocalDateTime hasta, Pageable pagina);

    @Query("""
            select coalesce(sum(v.precioFinal), 0) from Viaje v where v.pasajero.id = :id
            and v.situacionViaje = :situacion and v.estadoViaje = :estado
            and v.fechaFin >= :desde and v.fechaFin < :hasta""")
    BigDecimal montoHistorialDePasajero(@Param("id") Long idPasajero, @Param("situacion") SituacionViaje situacion,
            @Param("estado") EstadoRegistro estado, @Param("desde") LocalDateTime desde,
            @Param("hasta") LocalDateTime hasta);

    @Query("""
            select coalesce(sum(v.precioFinal), 0) from Viaje v where v.conductor.id = :id
            and v.situacionViaje = :situacion and v.estadoViaje = :estado
            and v.fechaFin >= :desde and v.fechaFin < :hasta""")
    BigDecimal montoHistorialDeConductor(@Param("id") Long idConductor, @Param("situacion") SituacionViaje situacion,
            @Param("estado") EstadoRegistro estado, @Param("desde") LocalDateTime desde,
            @Param("hasta") LocalDateTime hasta);
}
