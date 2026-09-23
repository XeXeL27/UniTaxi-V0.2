package com.taxiuap.backend.vehicle.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.vehicle.entity.DocumentoConductor;
import com.taxiuap.backend.vehicle.enums.SituacionRevision;

/** Repositorio de documentos de conductor. */
public interface DocumentoConductorRepository extends JpaRepository<DocumentoConductor, Long> {

    List<DocumentoConductor> findByConductorId(Long idConductor);

    List<DocumentoConductor> findByConductorIdAndEstadoDocumentoConductorOrderByIdAsc(Long idConductor,
            EstadoRegistro estado);

    List<DocumentoConductor> findByEstadoDocumentoConductor(EstadoRegistro estado);

    List<DocumentoConductor> findBySituacionRevisionAndEstadoDocumentoConductor(SituacionRevision situacionRevision,
            EstadoRegistro estado);

    List<DocumentoConductor> findBySituacionRevision(SituacionRevision situacionRevision);

    List<DocumentoConductor> findByConductorIdAndSituacionRevision(Long idConductor, SituacionRevision situacionRevision);
}
