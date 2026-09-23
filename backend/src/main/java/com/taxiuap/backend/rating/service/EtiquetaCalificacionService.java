package com.taxiuap.backend.rating.service;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.rating.dto.EtiquetaCalificacionRequest;
import com.taxiuap.backend.rating.dto.EtiquetaCalificacionResponse;
import com.taxiuap.backend.rating.entity.EtiquetaCalificacion;
import com.taxiuap.backend.rating.enums.AplicaA;
import com.taxiuap.backend.rating.repository.EtiquetaCalificacionRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/** Administra el catalogo de etiquetas de calificacion. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class EtiquetaCalificacionService {

    private final EtiquetaCalificacionRepository etiquetaCalificacionRepository;

    public List<EtiquetaCalificacionResponse> listar(boolean incluirInactivos) {
        return etiquetaCalificacionRepository.findAll().stream()
                .filter(etiqueta -> incluirInactivos || etiqueta.getEstadoEtiqCalif() == EstadoRegistro.A)
                .map(this::aRespuesta)
                .toList();
    }

    public List<EtiquetaCalificacionResponse> listarPorAplicaA(AplicaA aplicaA) {
        return etiquetaCalificacionRepository.findByAplicaA(aplicaA).stream()
                .filter(etiqueta -> etiqueta.getEstadoEtiqCalif() == EstadoRegistro.A)
                .map(this::aRespuesta)
                .toList();
    }

    public EtiquetaCalificacionResponse obtener(Integer id) {
        return aRespuesta(buscarPorId(id));
    }

    @Transactional
    public EtiquetaCalificacionResponse crear(EtiquetaCalificacionRequest request) {
        EtiquetaCalificacion etiqueta = new EtiquetaCalificacion();
        etiqueta.setNombre(request.nombre());
        etiqueta.setTipo(request.tipo());
        etiqueta.setAplicaA(request.aplicaA());
        etiqueta.setEstadoEtiqCalif(EstadoRegistro.A);

        return aRespuesta(etiquetaCalificacionRepository.save(etiqueta));
    }

    @Transactional
    public EtiquetaCalificacionResponse actualizar(Integer id, EtiquetaCalificacionRequest request) {
        EtiquetaCalificacion etiqueta = buscarPorId(id);

        etiqueta.setNombre(request.nombre());
        etiqueta.setTipo(request.tipo());
        etiqueta.setAplicaA(request.aplicaA());

        return aRespuesta(etiquetaCalificacionRepository.save(etiqueta));
    }

    @Transactional
    public void eliminar(Integer id) {
        EtiquetaCalificacion etiqueta = buscarPorId(id);
        etiqueta.setEstadoEtiqCalif(EstadoRegistro.X);
        etiquetaCalificacionRepository.save(etiqueta);
    }

    private EtiquetaCalificacion buscarPorId(Integer id) {
        return etiquetaCalificacionRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("EtiquetaCalificacion", id));
    }

    private EtiquetaCalificacionResponse aRespuesta(EtiquetaCalificacion etiqueta) {
        return new EtiquetaCalificacionResponse(
                etiqueta.getId(),
                etiqueta.getNombre(),
                etiqueta.getTipo(),
                etiqueta.getAplicaA(),
                etiqueta.getEstadoEtiqCalif()
        );
    }
}
