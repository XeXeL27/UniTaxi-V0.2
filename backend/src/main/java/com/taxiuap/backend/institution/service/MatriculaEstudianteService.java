package com.taxiuap.backend.institution.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.institution.dto.MatriculaRequest;
import com.taxiuap.backend.institution.dto.MatriculaResponse;
import com.taxiuap.backend.institution.entity.Carrera;
import com.taxiuap.backend.institution.entity.Estudiante;
import com.taxiuap.backend.institution.entity.MatriculaEstudiante;
import com.taxiuap.backend.institution.entity.VerificacionEstudiante;
import com.taxiuap.backend.institution.enums.SituacionVerificacion;
import com.taxiuap.backend.institution.repository.CarreraRepository;
import com.taxiuap.backend.institution.repository.MatriculaEstudianteRepository;
import com.taxiuap.backend.institution.repository.VerificacionEstudianteRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/** Administra la matricula estudiantil que el pasajero envia a verificacion. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MatriculaEstudianteService {

    private final MatriculaEstudianteRepository matriculaEstudianteRepository;
    private final VerificacionEstudianteRepository verificacionEstudianteRepository;
    private final CarreraRepository carreraRepository;
    private final EstudianteService estudianteService;

    @Transactional
    public MatriculaResponse registrar(Long idUsuario, MatriculaRequest datos) {
        Estudiante estudiante = estudianteService.buscarPorUsuario(idUsuario)
                .orElseThrow(() -> new NegocioException("Primero debe registrar sus datos de estudiante"));

        Carrera carrera = carreraRepository.findById(datos.idCarrera())
                .orElseThrow(() -> RecursoNoEncontradoException.de("Carrera", datos.idCarrera()));

        if (!carrera.getInstitucion().getId().equals(estudiante.getInstitucion().getId())) {
            throw new NegocioException("La carrera no pertenece a la institucion del estudiante");
        }

        boolean tienePendiente = matriculaEstudianteRepository.findByEstudianteId(estudiante.getId()).stream()
                .anyMatch(matricula -> matricula.getSituacionVerificacion() == SituacionVerificacion.PENDIENTE);
        if (tienePendiente) {
            throw new NegocioException("Ya tiene una matricula en revision");
        }

        MatriculaEstudiante matricula = new MatriculaEstudiante();
        matricula.setEstudiante(estudiante);
        matricula.setCarrera(carrera);
        matricula.setCursoGrado(datos.cursoGrado());
        matricula.setPeriodoAcademico(datos.periodoAcademico());
        matricula.setPlanEstudio(datos.planEstudio());
        matricula.setCodigoMatricula(datos.codigoMatricula());
        matricula.setFechaMatricula(LocalDateTime.now());
        matricula.setImagenMatriculaUrl(datos.imagenMatriculaUrl());
        // Nace en PENDIENTE: solo un administrador puede aprobarla o rechazarla.
        matricula.setSituacionVerificacion(SituacionVerificacion.PENDIENTE);
        matricula.setFechaVencimiento(datos.fechaVencimiento());
        matricula = matriculaEstudianteRepository.save(matricula);

        VerificacionEstudiante verificacion = new VerificacionEstudiante();
        verificacion.setMatricula(matricula);
        verificacion.setFechaEnvio(LocalDateTime.now());
        verificacionEstudianteRepository.save(verificacion);

        return aRespuesta(matricula, null);
    }

    public List<MatriculaResponse> listarPropias(Long idUsuario) {
        return estudianteService.buscarPorUsuario(idUsuario)
                .map(estudiante -> matriculaEstudianteRepository.findByEstudianteId(estudiante.getId()).stream()
                        .sorted(Comparator.comparing(MatriculaEstudiante::getFechaMatricula).reversed())
                        .map(matricula -> aRespuesta(matricula, motivoRechazo(matricula.getId())))
                        .toList())
                .orElseGet(List::of);
    }

    /**
     * Busca la matricula vigente aprobada de un estudiante. La usara el calculo de precio del
     * viaje (regla de negocio 3) para saber si corresponde aplicar el descuento estudiantil.
     */
    public Optional<MatriculaEstudiante> buscarVigenteAprobada(Long idEstudiante) {
        LocalDate hoy = LocalDate.now();
        return matriculaEstudianteRepository.findByEstudianteId(idEstudiante).stream()
                .filter(matricula -> matricula.getSituacionVerificacion() == SituacionVerificacion.APROBADA)
                .filter(matricula -> matricula.getEstadoMatEst() == EstadoRegistro.A)
                .filter(matricula -> matricula.getFechaVencimiento() == null
                        || !matricula.getFechaVencimiento().isBefore(hoy))
                .findFirst();
    }

    private String motivoRechazo(Long idMatricula) {
        return verificacionEstudianteRepository.findByMatriculaId(idMatricula).stream()
                .max(Comparator.comparing(VerificacionEstudiante::getFechaEnvio))
                .map(VerificacionEstudiante::getMotivoRechazo)
                .orElse(null);
    }

    private MatriculaResponse aRespuesta(MatriculaEstudiante matricula, String motivoRechazo) {
        return new MatriculaResponse(
                matricula.getId(),
                matricula.getCarrera().getId(),
                matricula.getCarrera().getNombre(),
                matricula.getEstudiante().getInstitucion().getNombre(),
                matricula.getCursoGrado(),
                matricula.getPeriodoAcademico(),
                matricula.getPlanEstudio(),
                matricula.getCodigoMatricula(),
                matricula.getImagenMatriculaUrl(),
                matricula.getFechaMatricula(),
                matricula.getSituacionVerificacion(),
                matricula.getFechaVencimiento(),
                motivoRechazo
        );
    }
}
