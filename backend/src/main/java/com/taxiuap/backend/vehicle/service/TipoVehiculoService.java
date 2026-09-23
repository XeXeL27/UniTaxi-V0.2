package com.taxiuap.backend.vehicle.service;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.vehicle.dto.TipoVehiculoRequest;
import com.taxiuap.backend.vehicle.dto.TipoVehiculoResponse;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;

import lombok.RequiredArgsConstructor;

/** Administra el catalogo de tipos de vehiculo. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TipoVehiculoService {

    private final TipoVehiculoRepository tipoVehiculoRepository;

    public List<TipoVehiculoResponse> listar(boolean incluirInactivos) {
        return tipoVehiculoRepository.findAll().stream()
                .filter(tipo -> incluirInactivos || tipo.getEstadoTipoVehiculo() == EstadoRegistro.A)
                .map(this::aRespuesta)
                .toList();
    }

    public TipoVehiculoResponse obtener(Integer id) {
        return aRespuesta(buscarPorId(id));
    }

    @Transactional
    public TipoVehiculoResponse crear(TipoVehiculoRequest request) {
        tipoVehiculoRepository.findByCodigo(request.codigo()).ifPresent(existente -> {
            throw new NegocioException("Ya existe un tipo de vehiculo con el codigo " + request.codigo());
        });

        TipoVehiculo tipoVehiculo = new TipoVehiculo();
        tipoVehiculo.setCodigo(request.codigo());
        tipoVehiculo.setNombre(request.nombre());
        tipoVehiculo.setCapacidadPasajeros(request.capacidadPasajeros());
        tipoVehiculo.setEstadoTipoVehiculo(EstadoRegistro.A);

        return aRespuesta(tipoVehiculoRepository.save(tipoVehiculo));
    }

    @Transactional
    public TipoVehiculoResponse actualizar(Integer id, TipoVehiculoRequest request) {
        TipoVehiculo tipoVehiculo = buscarPorId(id);

        tipoVehiculoRepository.findByCodigo(request.codigo())
                .filter(existente -> !existente.getId().equals(id))
                .ifPresent(existente -> {
                    throw new NegocioException("Ya existe un tipo de vehiculo con el codigo " + request.codigo());
                });

        tipoVehiculo.setCodigo(request.codigo());
        tipoVehiculo.setNombre(request.nombre());
        tipoVehiculo.setCapacidadPasajeros(request.capacidadPasajeros());

        return aRespuesta(tipoVehiculoRepository.save(tipoVehiculo));
    }

    @Transactional
    public void eliminar(Integer id) {
        TipoVehiculo tipoVehiculo = buscarPorId(id);
        tipoVehiculo.setEstadoTipoVehiculo(EstadoRegistro.X);
        tipoVehiculoRepository.save(tipoVehiculo);
    }

    private TipoVehiculo buscarPorId(Integer id) {
        return tipoVehiculoRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("TipoVehiculo", id));
    }

    private TipoVehiculoResponse aRespuesta(TipoVehiculo tipoVehiculo) {
        return new TipoVehiculoResponse(
                tipoVehiculo.getId(),
                tipoVehiculo.getCodigo(),
                tipoVehiculo.getNombre(),
                tipoVehiculo.getCapacidadPasajeros(),
                tipoVehiculo.getEstadoTipoVehiculo()
        );
    }
}
