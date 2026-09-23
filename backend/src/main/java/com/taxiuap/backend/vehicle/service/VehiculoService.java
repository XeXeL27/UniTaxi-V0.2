package com.taxiuap.backend.vehicle.service;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.vehicle.dto.VehiculoRequest;
import com.taxiuap.backend.vehicle.dto.VehiculoResponse;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

import lombok.RequiredArgsConstructor;

/** Administracion de los vehiculos del conductor autenticado. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class VehiculoService {

    private final VehiculoRepository vehiculoRepository;
    private final ConductorRepository conductorRepository;
    private final TipoVehiculoRepository tipoVehiculoRepository;
    private final CategoriaServicioRepository categoriaServicioRepository;

    public List<VehiculoResponse> listar(Long idUsuario) {
        Conductor conductor = buscarConductor(idUsuario);
        return vehiculoRepository.findByConductorId(conductor.getId()).stream()
                .map(this::aRespuesta)
                .toList();
    }

    @Transactional
    public VehiculoResponse crear(Long idUsuario, VehiculoRequest request) {
        Conductor conductor = buscarConductor(idUsuario);
        validarPlacaDisponible(request.placa(), null);

        TipoVehiculo tipoVehiculo = buscarTipoVehiculo(request.idTipoVehiculo());
        CategoriaServicio categoriaServicio = buscarCategoriaServicio(request.idCategoriaServicio());
        validarCategoriaDelTipo(tipoVehiculo, categoriaServicio);

        Vehiculo vehiculo = new Vehiculo();
        vehiculo.setConductor(conductor);
        vehiculo.setTipoVehiculo(tipoVehiculo);
        vehiculo.setCategoriaServicio(categoriaServicio);
        vehiculo.setPlaca(request.placa());
        vehiculo.setMarca(request.marca());
        vehiculo.setModelo(request.modelo());
        vehiculo.setColor(request.color());
        vehiculo.setAnio(request.anio());
        vehiculo.setEstadoVehiculo(EstadoRegistro.A);

        return aRespuesta(vehiculoRepository.save(vehiculo));
    }

    @Transactional
    public VehiculoResponse actualizar(Long idUsuario, Long id, VehiculoRequest request) {
        Conductor conductor = buscarConductor(idUsuario);
        Vehiculo vehiculo = buscarDelConductor(id, conductor.getId());
        validarPlacaDisponible(request.placa(), vehiculo.getId());

        TipoVehiculo tipoVehiculo = buscarTipoVehiculo(request.idTipoVehiculo());
        CategoriaServicio categoriaServicio = buscarCategoriaServicio(request.idCategoriaServicio());
        validarCategoriaDelTipo(tipoVehiculo, categoriaServicio);

        vehiculo.setTipoVehiculo(tipoVehiculo);
        vehiculo.setCategoriaServicio(categoriaServicio);
        vehiculo.setPlaca(request.placa());
        vehiculo.setMarca(request.marca());
        vehiculo.setModelo(request.modelo());
        vehiculo.setColor(request.color());
        vehiculo.setAnio(request.anio());

        return aRespuesta(vehiculoRepository.save(vehiculo));
    }

    @Transactional
    public void eliminar(Long idUsuario, Long id) {
        Conductor conductor = buscarConductor(idUsuario);
        Vehiculo vehiculo = buscarDelConductor(id, conductor.getId());
        vehiculo.setEstadoVehiculo(EstadoRegistro.X);
        vehiculoRepository.save(vehiculo);
    }

    private Conductor buscarConductor(Long idUsuario) {
        return conductorRepository.findByUsuarioId(idUsuario)
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de conductor"));
    }

    private Vehiculo buscarDelConductor(Long id, Long idConductor) {
        Vehiculo vehiculo = vehiculoRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Vehiculo", id));
        if (vehiculo.getConductor() == null || !vehiculo.getConductor().getId().equals(idConductor)) {
            throw RecursoNoEncontradoException.de("Vehiculo", id);
        }
        return vehiculo;
    }

    private void validarPlacaDisponible(String placa, Long idVehiculoActual) {
        vehiculoRepository.findByPlaca(placa).ifPresent(existente -> {
            if (idVehiculoActual == null || !existente.getId().equals(idVehiculoActual)) {
                throw new NegocioException("Ya existe un vehiculo con esa placa");
            }
        });
    }

    private TipoVehiculo buscarTipoVehiculo(Integer id) {
        return tipoVehiculoRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("TipoVehiculo", id));
    }

    private CategoriaServicio buscarCategoriaServicio(Integer id) {
        return categoriaServicioRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("CategoriaServicio", id));
    }

    private void validarCategoriaDelTipo(TipoVehiculo tipoVehiculo, CategoriaServicio categoriaServicio) {
        if (categoriaServicio.getTipoVehiculo() == null
                || !categoriaServicio.getTipoVehiculo().getId().equals(tipoVehiculo.getId())) {
            throw new NegocioException("La categoria de servicio no corresponde al tipo de vehiculo");
        }
    }

    private VehiculoResponse aRespuesta(Vehiculo vehiculo) {
        return new VehiculoResponse(
                vehiculo.getId(),
                vehiculo.getPlaca(),
                vehiculo.getMarca(),
                vehiculo.getModelo(),
                vehiculo.getColor(),
                vehiculo.getAnio(),
                vehiculo.getTipoVehiculo() != null ? vehiculo.getTipoVehiculo().getId() : null,
                vehiculo.getTipoVehiculo() != null ? vehiculo.getTipoVehiculo().getNombre() : null,
                vehiculo.getCategoriaServicio() != null ? vehiculo.getCategoriaServicio().getId() : null,
                vehiculo.getCategoriaServicio() != null ? vehiculo.getCategoriaServicio().getNombre() : null,
                vehiculo.getEstadoVehiculo());
    }
}
