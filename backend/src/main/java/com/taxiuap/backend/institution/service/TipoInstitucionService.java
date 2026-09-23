package com.taxiuap.backend.institution.service;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.institution.dto.TipoInstitucionRequest;
import com.taxiuap.backend.institution.dto.TipoInstitucionResponse;
import com.taxiuap.backend.institution.entity.TipoInstitucion;
import com.taxiuap.backend.institution.repository.TipoInstitucionRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/** Administra el catalogo de tipos de institucion educativa. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TipoInstitucionService {

    private final TipoInstitucionRepository tipoInstitucionRepository;

    public List<TipoInstitucionResponse> listar(boolean incluirInactivos) {
        return tipoInstitucionRepository.findAll().stream()
                .filter(tipo -> incluirInactivos || tipo.getEstadoTipoInst() == EstadoRegistro.A)
                .map(this::aRespuesta)
                .toList();
    }

    public TipoInstitucionResponse obtener(Integer id) {
        return aRespuesta(buscarPorId(id));
    }

    @Transactional
    public TipoInstitucionResponse crear(TipoInstitucionRequest request) {
        tipoInstitucionRepository.findByCodigo(request.codigo()).ifPresent(existente -> {
            throw new NegocioException("Ya existe un tipo de institucion con el codigo " + request.codigo());
        });

        TipoInstitucion tipoInstitucion = new TipoInstitucion();
        tipoInstitucion.setCodigo(request.codigo());
        tipoInstitucion.setNombre(request.nombre());
        tipoInstitucion.setEstadoTipoInst(EstadoRegistro.A);

        return aRespuesta(tipoInstitucionRepository.save(tipoInstitucion));
    }

    @Transactional
    public TipoInstitucionResponse actualizar(Integer id, TipoInstitucionRequest request) {
        TipoInstitucion tipoInstitucion = buscarPorId(id);

        tipoInstitucionRepository.findByCodigo(request.codigo())
                .filter(existente -> !existente.getId().equals(id))
                .ifPresent(existente -> {
                    throw new NegocioException("Ya existe un tipo de institucion con el codigo " + request.codigo());
                });

        tipoInstitucion.setCodigo(request.codigo());
        tipoInstitucion.setNombre(request.nombre());

        return aRespuesta(tipoInstitucionRepository.save(tipoInstitucion));
    }

    @Transactional
    public void eliminar(Integer id) {
        TipoInstitucion tipoInstitucion = buscarPorId(id);
        tipoInstitucion.setEstadoTipoInst(EstadoRegistro.X);
        tipoInstitucionRepository.save(tipoInstitucion);
    }

    private TipoInstitucion buscarPorId(Integer id) {
        return tipoInstitucionRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("TipoInstitucion", id));
    }

    private TipoInstitucionResponse aRespuesta(TipoInstitucion tipoInstitucion) {
        return new TipoInstitucionResponse(
                tipoInstitucion.getId(),
                tipoInstitucion.getCodigo(),
                tipoInstitucion.getNombre(),
                tipoInstitucion.getEstadoTipoInst()
        );
    }
}
