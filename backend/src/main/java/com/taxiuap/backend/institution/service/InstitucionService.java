package com.taxiuap.backend.institution.service;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.institution.dto.InstitucionRequest;
import com.taxiuap.backend.institution.dto.InstitucionResponse;
import com.taxiuap.backend.institution.entity.Institucion;
import com.taxiuap.backend.institution.entity.TipoInstitucion;
import com.taxiuap.backend.institution.repository.InstitucionRepository;
import com.taxiuap.backend.institution.repository.TipoInstitucionRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/** Administra el catalogo de instituciones educativas. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class InstitucionService {

    private final InstitucionRepository institucionRepository;
    private final TipoInstitucionRepository tipoInstitucionRepository;

    public List<InstitucionResponse> listar(boolean incluirInactivos) {
        return institucionRepository.findAll().stream()
                .filter(institucion -> incluirInactivos || institucion.getEstadoInst() == EstadoRegistro.A)
                .map(this::aRespuesta)
                .toList();
    }

    public List<InstitucionResponse> listarPorTipo(Integer idTipoInstitucion) {
        return institucionRepository.findByTipoInstitucionId(idTipoInstitucion).stream()
                .filter(institucion -> institucion.getEstadoInst() == EstadoRegistro.A)
                .map(this::aRespuesta)
                .toList();
    }

    public InstitucionResponse obtener(Long id) {
        return aRespuesta(buscarPorId(id));
    }

    @Transactional
    public InstitucionResponse crear(InstitucionRequest request) {
        TipoInstitucion tipoInstitucion = buscarTipoInstitucion(request.idTipoInstitucion());

        Institucion institucion = new Institucion();
        institucion.setTipoInstitucion(tipoInstitucion);
        institucion.setNombre(request.nombre());
        institucion.setSigla(request.sigla());
        institucion.setCiudad(request.ciudad());
        institucion.setEstadoInst(EstadoRegistro.A);

        return aRespuesta(institucionRepository.save(institucion));
    }

    @Transactional
    public InstitucionResponse actualizar(Long id, InstitucionRequest request) {
        Institucion institucion = buscarPorId(id);
        TipoInstitucion tipoInstitucion = buscarTipoInstitucion(request.idTipoInstitucion());

        institucion.setTipoInstitucion(tipoInstitucion);
        institucion.setNombre(request.nombre());
        institucion.setSigla(request.sigla());
        institucion.setCiudad(request.ciudad());

        return aRespuesta(institucionRepository.save(institucion));
    }

    @Transactional
    public void eliminar(Long id) {
        Institucion institucion = buscarPorId(id);
        institucion.setEstadoInst(EstadoRegistro.X);
        institucionRepository.save(institucion);
    }

    private Institucion buscarPorId(Long id) {
        return institucionRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Institucion", id));
    }

    private TipoInstitucion buscarTipoInstitucion(Integer idTipoInstitucion) {
        return tipoInstitucionRepository.findById(idTipoInstitucion)
                .orElseThrow(() -> RecursoNoEncontradoException.de("TipoInstitucion", idTipoInstitucion));
    }

    private InstitucionResponse aRespuesta(Institucion institucion) {
        return new InstitucionResponse(
                institucion.getId(),
                institucion.getTipoInstitucion().getId(),
                institucion.getTipoInstitucion().getNombre(),
                institucion.getNombre(),
                institucion.getSigla(),
                institucion.getCiudad(),
                institucion.getEstadoInst()
        );
    }
}
