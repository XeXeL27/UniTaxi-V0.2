package com.taxiuap.backend.trip.repository;

import java.util.Collection;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;

/** Repositorio de solicitudes de viaje. */
public interface SolicitudViajeRepository extends JpaRepository<SolicitudViaje, Long> {

    List<SolicitudViaje> findByPasajeroIdOrderByFechaSolicitudDesc(Long idPasajero);

    List<SolicitudViaje> findBySituacionSolicitud(SituacionSolicitud situacionSolicitud);

    boolean existsByPasajeroIdAndSituacionSolicitudIn(Long idPasajero, Collection<SituacionSolicitud> situaciones);

    /**
     * Aceptar una oferta es la operacion critica de la regla de negocio 5: dos ofertas no pueden
     * ganar la misma solicitud. En vez de leer la situacion en Java y despues escribirla (lo que
     * dejaria una ventana de tiempo donde dos peticiones concurrentes leen "disponible" y las dos
     * escriben), el cambio de estado se hace en un unico UPDATE condicional: la clausula WHERE
     * exige que la solicitud siga PENDIENTE o CON_OFERTAS. PostgreSQL serializa los UPDATE sobre
     * la misma fila, asi que de dos peticiones simultaneas una obtiene el bloqueo primero, cambia
     * la fila y devuelve 1; la otra, cuando por fin corre, ya no encuentra la fila en esa
     * situacion y devuelve 0. Es exactamente la misma garantia que evita vender dos veces un
     * puesto en uniFex (IPuestoDao.reservarSiLibre).
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update SolicitudViaje s set s.situacionSolicitud = com.taxiuap.backend.trip.enums.SituacionSolicitud.ACEPTADA "
            + "where s.id = :id and s.situacionSolicitud in "
            + "(com.taxiuap.backend.trip.enums.SituacionSolicitud.PENDIENTE, "
            + "com.taxiuap.backend.trip.enums.SituacionSolicitud.CON_OFERTAS)")
    int aceptarSiDisponible(@Param("id") Long id);
}
