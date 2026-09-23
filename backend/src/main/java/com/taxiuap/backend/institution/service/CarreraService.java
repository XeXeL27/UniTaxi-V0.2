package com.taxiuap.backend.institution.service;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.institution.dto.CarreraRequest;
import com.taxiuap.backend.institution.dto.CarreraResponse;
import com.taxiuap.backend.institution.entity.Carrera;
import com.taxiuap.backend.institution.entity.Institucion;
import com.taxiuap.backend.institution.repository.CarreraRepository;
import com.taxiuap.backend.institution.repository.InstitucionRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/** Administra el catalogo de carreras academicas. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CarreraService {

    private final CarreraRepository carreraRepository;
    private final InstitucionRepository institucionRepository;

    public List<CarreraResponse> listar(boolean incluirInactivos) {
        return carreraRepository.findAll().stream()
                .filter(carrera -> incluirInactivos || carrera.getEstadoCarrera() == EstadoRegistro.A)
                .map(this::aRespuesta)
                .toList();
    }

    public List<CarreraResponse> listarPorInstitucion(Long idInstitucion) {
        return carreraRepository.findByInstitucionId(idInstitucion).stream()
                .filter(carrera -> carrera.getEstadoCarrera() == EstadoRegistro.A)
                .map(this::aRespuesta)
                .toList();
    }

    public CarreraResponse obtener(Long id) {
        return aRespuesta(buscarPorId(id));
    }

    @Transactional
    public CarreraResponse crear(CarreraRequest request) {
        Institucion institucion = buscarInstitucion(request.idInstitucion());

        Carrera carrera = new Carrera();
        carrera.setInstitucion(institucion);
        carrera.setNombre(request.nombre());
        carrera.setEstadoCarrera(EstadoRegistro.A);

        return aRespuesta(carreraRepository.save(carrera));
    }

    @Transactional
    public CarreraResponse actualizar(Long id, CarreraRequest request) {
        Carrera carrera = buscarPorId(id);
        Institucion institucion = buscarInstitucion(request.idInstitucion());

        carrera.setInstitucion(institucion);
        carrera.setNombre(request.nombre());

        return aRespuesta(carreraRepository.save(carrera));
    }

    @Transactional
    public void eliminar(Long id) {
        Carrera carrera = buscarPorId(id);
        carrera.setEstadoCarrera(EstadoRegistro.X);
        carreraRepository.save(carrera);
    }

    private Carrera buscarPorId(Long id) {
        return carreraRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Carrera", id));
    }

    private Institucion buscarInstitucion(Long idInstitucion) {
        return institucionRepository.findById(idInstitucion)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Institucion", idInstitucion));
    }

    private CarreraResponse aRespuesta(Carrera carrera) {
        return new CarreraResponse(
                carrera.getId(),
                carrera.getInstitucion().getId(),
                carrera.getInstitucion().getNombre(),
                carrera.getNombre(),
                carrera.getEstadoCarrera()
        );
    }
}
