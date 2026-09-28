package com.taxiuap.backend.vehicle.service;

import java.time.LocalDate;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.entity.Administrador;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.enums.TipoPermisoEdicion;
import com.taxiuap.backend.identity.service.PermisoEdicionService;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.vehicle.dto.DocumentoConductorAdminResponse;
import com.taxiuap.backend.vehicle.dto.ActualizarDocumentoRequest;
import com.taxiuap.backend.vehicle.dto.DocumentoConductorResponse;
import com.taxiuap.backend.vehicle.dto.RevisionDocumentoRequest;
import com.taxiuap.backend.vehicle.entity.DocumentoConductor;
import com.taxiuap.backend.vehicle.enums.SituacionRevision;
import com.taxiuap.backend.vehicle.repository.DocumentoConductorRepository;

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
    private final AlmacenamientoArchivos almacenamientoArchivos;
    private final PermisoEdicionService permisoEdicionService;

    public List<DocumentoConductorResponse> listar(Long idUsuario) {
        Conductor conductor = buscarConductor(idUsuario);
        return documentoConductorRepository
                .findByConductorIdAndEstadoDocumentoConductorOrderByIdAsc(conductor.getId(), EstadoRegistro.A).stream()
                .map(this::aRespuesta)
                .toList();
    }

    /** Documento activo del conductor autenticado, para ver su PDF. */
    public DocumentoConductor obtenerDelConductor(Long idUsuario, Long id) {
        Conductor conductor = buscarConductor(idUsuario);
        DocumentoConductor documento = buscarDelConductor(id, conductor.getId());
        if (documento.getEstadoDocumentoConductor() != EstadoRegistro.A) {
            throw RecursoNoEncontradoException.de("DocumentoConductor", id);
        }
        return documento;
    }

    /**
     * El conductor reemplaza el PDF de un documento. Necesita un permiso vigente del administrador
     * para ese documento; el permiso se cierra al usarlo y el documento vuelve a PENDIENTE.
     */
    @Transactional
    public DocumentoConductorResponse reemplazarArchivo(Long idUsuario, Long id, MultipartFile archivo) {
        DocumentoConductor documento = obtenerDelConductor(idUsuario, id);
        almacenamientoArchivos.validarPdf(archivo, documento.getTipoDocumento().name());
        permisoEdicionService.consumir(documento.getConductor().getId(), TipoPermisoEdicion.DOCUMENTO, id);
        guardarNuevoArchivo(documento, archivo);
        documento.setSituacionRevision(SituacionRevision.PENDIENTE);
        documento.setAdminRevisor(null);
        return aRespuesta(documento);
    }

    /** El administrador corrige el tipo o la fecha de vencimiento de un documento. */
    @Transactional
    public DocumentoConductorAdminResponse actualizarDatos(Long id, ActualizarDocumentoRequest request) {
        DocumentoConductor documento = obtenerActivo(id);
        documento.setTipoDocumento(request.tipoDocumento());
        documento.setFechaVencimiento(request.fechaVencimiento());
        return aRespuestaAdmin(documento);
    }

    /** El administrador reemplaza el PDF; la situacion de revision no cambia. */
    @Transactional
    public DocumentoConductorAdminResponse reemplazarArchivoAdmin(Long id, MultipartFile archivo) {
        DocumentoConductor documento = obtenerActivo(id);
        almacenamientoArchivos.validarPdf(archivo, documento.getTipoDocumento().name());
        guardarNuevoArchivo(documento, archivo);
        return aRespuestaAdmin(documento);
    }

    /** Borrado logico del documento. El PDF se conserva en la carpeta de la persona. */
    @Transactional
    public void eliminar(Long id) {
        obtenerActivo(id).setEstadoDocumentoConductor(EstadoRegistro.X);
    }

    private void guardarNuevoArchivo(DocumentoConductor documento, MultipartFile archivo) {
        Persona persona = documento.getConductor().getUsuario().getPersona();
        documento.setArchivoUrl(almacenamientoArchivos.guardarPdf(archivo,
                almacenamientoArchivos.carpetaDocumentosConductor(persona), documento.getTipoDocumento().name()));
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

        List<DocumentoConductor> documentos = documentoConductorRepository
                .findByConductorIdAndEstadoDocumentoConductorOrderByIdAsc(idConductor, EstadoRegistro.A);
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
