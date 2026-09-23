package com.taxiuap.backend.institution.service;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.entity.Administrador;
import com.taxiuap.backend.identity.repository.AdministradorRepository;
import com.taxiuap.backend.institution.dto.ResolverVerificacionRequest;
import com.taxiuap.backend.institution.dto.VerificacionPendienteResponse;
import com.taxiuap.backend.institution.entity.Estudiante;
import com.taxiuap.backend.institution.entity.MatriculaEstudiante;
import com.taxiuap.backend.institution.entity.VerificacionEstudiante;
import com.taxiuap.backend.institution.enums.ResultadoVerificacion;
import com.taxiuap.backend.institution.enums.SituacionVerificacion;
import com.taxiuap.backend.institution.repository.MatriculaEstudianteRepository;
import com.taxiuap.backend.institution.repository.VerificacionEstudianteRepository;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/** Revision administrativa de las matriculas estudiantiles enviadas por los pasajeros. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class VerificacionEstudianteService {

    private final MatriculaEstudianteRepository matriculaEstudianteRepository;
    private final VerificacionEstudianteRepository verificacionEstudianteRepository;
    private final AdministradorRepository administradorRepository;

    public List<VerificacionPendienteResponse> listarPendientes() {
        return matriculaEstudianteRepository.findBySituacionVerificacion(SituacionVerificacion.PENDIENTE).stream()
                .map(this::aRespuestaPendiente)
                .toList();
    }

    @Transactional
    public void resolver(Long idMatricula, ResolverVerificacionRequest datos, Long idUsuarioAdmin) {
        if (datos.resultado() == ResultadoVerificacion.RECHAZADO
                && (datos.motivoRechazo() == null || datos.motivoRechazo().isBlank())) {
            throw new NegocioException("Debe indicar el motivo del rechazo");
        }

        MatriculaEstudiante matricula = matriculaEstudianteRepository.findById(idMatricula)
                .orElseThrow(() -> RecursoNoEncontradoException.de("MatriculaEstudiante", idMatricula));

        if (matricula.getSituacionVerificacion() != SituacionVerificacion.PENDIENTE) {
            throw new NegocioException("La matricula ya fue revisada");
        }

        VerificacionEstudiante verificacion = verificacionEstudianteRepository.findByMatriculaId(idMatricula).stream()
                .filter(v -> v.getResultado() == null)
                .max(Comparator.comparing(VerificacionEstudiante::getFechaEnvio))
                .orElseThrow(() -> RecursoNoEncontradoException.de("VerificacionEstudiante", idMatricula));

        Administrador adminRevisor = administradorRepository.findByUsuarioId(idUsuarioAdmin)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Administrador", idUsuarioAdmin));

        verificacion.setResultado(datos.resultado());
        verificacion.setFechaRevision(LocalDateTime.now());
        verificacion.setAdminRevisor(adminRevisor);
        verificacion.setMotivoRechazo(datos.motivoRechazo());
        verificacionEstudianteRepository.save(verificacion);

        matricula.setSituacionVerificacion(datos.resultado() == ResultadoVerificacion.APROBADO
                ? SituacionVerificacion.APROBADA
                : SituacionVerificacion.RECHAZADA);
        matriculaEstudianteRepository.save(matricula);
    }

    private VerificacionPendienteResponse aRespuestaPendiente(MatriculaEstudiante matricula) {
        Estudiante estudiante = matricula.getEstudiante();
        LocalDateTime fechaEnvio = verificacionEstudianteRepository.findByMatriculaId(matricula.getId()).stream()
                .filter(v -> v.getResultado() == null)
                .max(Comparator.comparing(VerificacionEstudiante::getFechaEnvio))
                .map(VerificacionEstudiante::getFechaEnvio)
                .orElse(matricula.getFechaMatricula());

        return new VerificacionPendienteResponse(
                matricula.getId(),
                estudiante.getId(),
                estudiante.getPersona().getNombres() + " " + estudiante.getPersona().getApellidos(),
                estudiante.getCodigoEstudiante(),
                estudiante.getInstitucion().getNombre(),
                matricula.getCarrera().getNombre(),
                matricula.getImagenMatriculaUrl(),
                fechaEnvio
        );
    }
}
