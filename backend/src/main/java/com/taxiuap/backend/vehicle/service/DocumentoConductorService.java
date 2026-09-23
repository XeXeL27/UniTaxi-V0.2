package com.taxiuap.backend.vehicle.service;

import java.time.LocalDate;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.entity.Administrador;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.vehicle.dto.DocumentoConductorAdminResponse;
import com.taxiuap.backend.vehicle.dto.DocumentoConductorRequest;
import com.taxiuap.backend.vehicle.dto.DocumentoConductorResponse;
import com.taxiuap.backend.vehicle.dto.RevisionDocumentoRequest;
import com.taxiuap.backend.vehicle.entity.DocumentoConductor;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.enums.SituacionRevision;
import com.taxiuap.backend.vehicle.repository.DocumentoConductorRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

import lombok.RequiredArgsConstructor;

/**
 * Administracion de los documentos del conductor autenticado y revision administrativa de los
 * mismos.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class DocumentoConductorService {

    private final DocumentoConductorRepository documentoConductorRepository;
    private final ConductorRepository conductorRepository;
    private final VehiculoRepository vehiculoRepository;

    public List<DocumentoConductorResponse> listar(Long idUsuario) {
        Conductor conductor = buscarConductor(idUsuario);
        return documentoConductorRepository.findByConductorId(conductor.getId()).stream()
                .map(this::aRespuesta)
                .toList();
    }

    @Transactional
    public DocumentoConductorResponse crear(Long idUsuario, DocumentoConductorRequest request) {
        Conductor conductor = buscarConductor(idUsuario);

        DocumentoConductor documento = new DocumentoConductor();
        documento.setConductor(conductor);
        documento.setVehiculo(buscarVehiculoOpcional(request.idVehiculo()));
        documento.setTipoDocumento(request.tipoDocumento());
        documento.setArchivoUrl(request.archivoUrl());
        documento.setFechaVencimiento(request.fechaVencimiento());
        // Se crea siempre PENDIENTE: solo un administrador cambia la situacion de revision.
        documento.setSituacionRevision(SituacionRevision.PENDIENTE);
        documento.setEstadoDocumentoConductor(EstadoRegistro.A);

        return aRespuesta(documentoConductorRepository.save(documento));
    }

    @Transactional
    public DocumentoConductorResponse actualizar(Long idUsuario, Long id, DocumentoConductorRequest request) {
        Conductor conductor = buscarConductor(idUsuario);
        DocumentoConductor documento = buscarDelConductor(id, conductor.getId());

        documento.setVehiculo(buscarVehiculoOpcional(request.idVehiculo()));
        documento.setTipoDocumento(request.tipoDocumento());
        documento.setArchivoUrl(request.archivoUrl());
        documento.setFechaVencimiento(request.fechaVencimiento());
        // Al reemplazar el archivo vuelve a quedar pendiente de revision.
        documento.setSituacionRevision(SituacionRevision.PENDIENTE);

        return aRespuesta(documentoConductorRepository.save(documento));
    }

    public List<DocumentoConductorAdminResponse> listarParaAdmin(SituacionRevision situacion) {
        List<DocumentoConductor> documentos = situacion == null
                ? documentoConductorRepository.findByEstadoDocumentoConductor(EstadoRegistro.A)
                : documentoConductorRepository.findBySituacionRevisionAndEstadoDocumentoConductor(situacion,
                        EstadoRegistro.A);
        return documentos.stream().map(this::aRespuestaAdmin).toList();
    }

    public List<DocumentoConductorAdminResponse> listarDeConductor(Long idConductor) {
        return documentoConductorRepository
                .findByConductorIdAndEstadoDocumentoConductorOrderByIdAsc(idConductor, EstadoRegistro.A).stream()
                .map(this::aRespuestaAdmin)
                .toList();
    }

    /** Documento activo con su archivo, para descargar el PDF desde el panel admin. */
    public DocumentoConductor obtenerActivo(Long id) {
        return documentoConductorRepository.findById(id)
                .filter(documento -> documento.getEstadoDocumentoConductor() == EstadoRegistro.A)
                .orElseThrow(() -> RecursoNoEncontradoException.de("DocumentoConductor", id));
    }

    @Transactional
    public DocumentoConductorAdminResponse revisar(Long id, RevisionDocumentoRequest request, Administrador adminRevisor) {
        DocumentoConductor documento = documentoConductorRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("DocumentoConductor", id));

        documento.setSituacionRevision(request.situacion());
        documento.setAdminRevisor(adminRevisor);

        return aRespuestaAdmin(documentoConductorRepository.save(documento));
    }

    /**
     * Un conductor puede operar (recibir solicitudes de viaje) solo si esta APROBADO (regla de
     * negocio 1) y no tiene ningun documento vencido ni sin aprobar (regla de negocio 2). Este
     * metodo lo usara el flujo de viaje antes de ofertar o aceptar solicitudes.
     */
    public boolean puedeOperar(Long idConductor) {
        Conductor conductor = conductorRepository.findById(idConductor)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Conductor", idConductor));

        if (conductor.getSituacionAprobacion() != SituacionAprobacion.APROBADO) {
            return false;
        }

        List<DocumentoConductor> documentos = documentoConductorRepository.findByConductorId(idConductor);
        LocalDate hoy = LocalDate.now();

        return documentos.stream().allMatch(documento ->
                documento.getSituacionRevision() == SituacionRevision.APROBADO
                        && (documento.getFechaVencimiento() == null || !documento.getFechaVencimiento().isBefore(hoy)));
    }

    private Conductor buscarConductor(Long idUsuario) {
        return conductorRepository.findByUsuarioId(idUsuario)
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de conductor"));
    }

    private DocumentoConductor buscarDelConductor(Long id, Long idConductor) {
        DocumentoConductor documento = documentoConductorRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("DocumentoConductor", id));
        if (documento.getConductor() == null || !documento.getConductor().getId().equals(idConductor)) {
            throw RecursoNoEncontradoException.de("DocumentoConductor", id);
        }
        return documento;
    }

    private Vehiculo buscarVehiculoOpcional(Long idVehiculo) {
        if (idVehiculo == null) {
            return null;
        }
        return vehiculoRepository.findById(idVehiculo)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Vehiculo", idVehiculo));
    }

    private DocumentoConductorResponse aRespuesta(DocumentoConductor documento) {
        return new DocumentoConductorResponse(
                documento.getId(),
                documento.getConductor() != null ? documento.getConductor().getId() : null,
                documento.getVehiculo() != null ? documento.getVehiculo().getId() : null,
                documento.getTipoDocumento(),
                documento.getArchivoUrl(),
                documento.getFechaVencimiento(),
                documento.getSituacionRevision());
    }

    private DocumentoConductorAdminResponse aRespuestaAdmin(DocumentoConductor documento) {
        Conductor conductor = documento.getConductor();
        Persona persona = conductor != null && conductor.getUsuario() != null ? conductor.getUsuario().getPersona() : null;
        return new DocumentoConductorAdminResponse(
                documento.getId(),
                conductor != null ? conductor.getId() : null,
                persona != null ? persona.getNombres() : null,
                persona != null ? persona.getApellidos() : null,
                documento.getVehiculo() != null ? documento.getVehiculo().getId() : null,
                documento.getTipoDocumento(),
                documento.getArchivoUrl(),
                documento.getFechaVencimiento(),
                documento.getSituacionRevision(),
                documento.getAdminRevisor() != null ? documento.getAdminRevisor().getId() : null);
    }
}
