package com.taxiuap.backend.vehicle.service;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.vehicle.dto.CategoriaServicioRequest;
import com.taxiuap.backend.vehicle.dto.CategoriaServicioResponse;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;

import lombok.RequiredArgsConstructor;

/** Administra el catalogo de categorias de servicio. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CategoriaServicioService {

    private final CategoriaServicioRepository categoriaServicioRepository;
    private final TipoVehiculoRepository tipoVehiculoRepository;

    public List<CategoriaServicioResponse> listar(boolean incluirInactivos) {
        return categoriaServicioRepository.findAll().stream()
                .filter(categoria -> incluirInactivos || categoria.getEstadoCategoriaServicio() == EstadoRegistro.A)
                .map(this::aRespuesta)
                .toList();
    }

    public List<CategoriaServicioResponse> listarPorTipoVehiculo(Integer idTipoVehiculo) {
        return categoriaServicioRepository.findByTipoVehiculoId(idTipoVehiculo).stream()
                .filter(categoria -> categoria.getEstadoCategoriaServicio() == EstadoRegistro.A)
                .map(this::aRespuesta)
                .toList();
    }

    public CategoriaServicioResponse obtener(Integer id) {
        return aRespuesta(buscarPorId(id));
    }

    @Transactional
    public CategoriaServicioResponse crear(CategoriaServicioRequest request) {
        TipoVehiculo tipoVehiculo = buscarTipoVehiculo(request.idTipoVehiculo());

        CategoriaServicio categoriaServicio = new CategoriaServicio();
        categoriaServicio.setTipoVehiculo(tipoVehiculo);
        categoriaServicio.setNombre(request.nombre());
        categoriaServicio.setEstadoCategoriaServicio(EstadoRegistro.A);

        return aRespuesta(categoriaServicioRepository.save(categoriaServicio));
    }

    @Transactional
    public CategoriaServicioResponse actualizar(Integer id, CategoriaServicioRequest request) {
        CategoriaServicio categoriaServicio = buscarPorId(id);
        TipoVehiculo tipoVehiculo = buscarTipoVehiculo(request.idTipoVehiculo());

        categoriaServicio.setTipoVehiculo(tipoVehiculo);
        categoriaServicio.setNombre(request.nombre());

        return aRespuesta(categoriaServicioRepository.save(categoriaServicio));
    }

    @Transactional
    public void eliminar(Integer id) {
        CategoriaServicio categoriaServicio = buscarPorId(id);
        categoriaServicio.setEstadoCategoriaServicio(EstadoRegistro.X);
        categoriaServicioRepository.save(categoriaServicio);
    }

    private CategoriaServicio buscarPorId(Integer id) {
        return categoriaServicioRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("CategoriaServicio", id));
    }

    private TipoVehiculo buscarTipoVehiculo(Integer idTipoVehiculo) {
        return tipoVehiculoRepository.findById(idTipoVehiculo)
                .orElseThrow(() -> RecursoNoEncontradoException.de("TipoVehiculo", idTipoVehiculo));
    }

    private CategoriaServicioResponse aRespuesta(CategoriaServicio categoriaServicio) {
        return new CategoriaServicioResponse(
                categoriaServicio.getId(),
                categoriaServicio.getTipoVehiculo().getId(),
                categoriaServicio.getTipoVehiculo().getNombre(),
                categoriaServicio.getNombre(),
                categoriaServicio.getEstadoCategoriaServicio()
        );
    }
}
