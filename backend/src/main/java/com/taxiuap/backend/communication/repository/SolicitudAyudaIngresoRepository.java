package com.taxiuap.backend.communication.repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.communication.entity.SolicitudAyudaIngreso;
import com.taxiuap.backend.communication.enums.OrigenAyudaIngreso;
import com.taxiuap.backend.communication.enums.SituacionAyudaIngreso;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Mensajes al administrador de quienes no pueden ingresar a su cuenta. */
public interface SolicitudAyudaIngresoRepository extends JpaRepository<SolicitudAyudaIngreso, Long> {

    List<SolicitudAyudaIngreso> findByEstadoSolAyudaIngOrderByFechaDesc(EstadoRegistro estado);

    long countBySituacionAndEstadoSolAyudaIng(SituacionAyudaIngreso situacion, EstadoRegistro estado);

    /** El ultimo mensaje de la persona, para saber si sigue en las 24 horas de espera. */
    Optional<SolicitudAyudaIngreso> findFirstByPersonaIdAndOrigenInAndEstadoSolAyudaIngOrderByFechaDesc(Long idPersona,
            Collection<OrigenAyudaIngreso> origenes, EstadoRegistro estado);
}
