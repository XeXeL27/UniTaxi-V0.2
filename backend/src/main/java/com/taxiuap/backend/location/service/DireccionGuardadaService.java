package com.taxiuap.backend.location.service;

import java.util.List;

import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.locationtech.jts.io.ParseException;
import org.locationtech.jts.io.WKTReader;
import org.locationtech.jts.io.WKTWriter;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.location.dto.DireccionGuardadaRequest;
import com.taxiuap.backend.location.dto.DireccionGuardadaResponse;
import com.taxiuap.backend.location.entity.DireccionGuardada;
import com.taxiuap.backend.location.repository.DireccionGuardadaRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/** CRUD de las direcciones guardadas del pasajero autenticado, con borrado logico. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class DireccionGuardadaService {

    private static final int SRID_WGS84 = 4326;
    private static final GeometryFactory FABRICA_GEOMETRIA =
            new GeometryFactory(new PrecisionModel(), SRID_WGS84);

    private final DireccionGuardadaRepository direccionGuardadaRepository;
    private final PasajeroRepository pasajeroRepository;

    public List<DireccionGuardadaResponse> listar(Long idUsuario) {
        Pasajero pasajero = buscarPasajero(idUsuario);
        return direccionGuardadaRepository
                .findByPasajeroIdAndEstadoDireccionGuardada(pasajero.getId(), EstadoRegistro.A).stream()
                .map(this::aRespuesta)
                .toList();
    }

    @Transactional
    public DireccionGuardadaResponse crear(Long idUsuario, DireccionGuardadaRequest request) {
        Pasajero pasajero = buscarPasajero(idUsuario);

        DireccionGuardada direccion = new DireccionGuardada();
        direccion.setPasajero(pasajero);
        direccion.setNombre(request.nombre());
        direccion.setDireccion(request.direccion());
        direccion.setUbicacion(convertirAPunto(request.ubicacionWkt()));
        direccion.setEstadoDireccionGuardada(EstadoRegistro.A);

        return aRespuesta(direccionGuardadaRepository.save(direccion));
    }

    @Transactional
    public DireccionGuardadaResponse actualizar(Long idUsuario, Long id, DireccionGuardadaRequest request) {
        Pasajero pasajero = buscarPasajero(idUsuario);
        DireccionGuardada direccion = buscarDelPasajero(id, pasajero.getId());

        direccion.setNombre(request.nombre());
        direccion.setDireccion(request.direccion());
        direccion.setUbicacion(convertirAPunto(request.ubicacionWkt()));

        return aRespuesta(direccionGuardadaRepository.save(direccion));
    }

    @Transactional
    public void eliminar(Long idUsuario, Long id) {
        Pasajero pasajero = buscarPasajero(idUsuario);
        DireccionGuardada direccion = buscarDelPasajero(id, pasajero.getId());
        direccion.setEstadoDireccionGuardada(EstadoRegistro.X);
        direccionGuardadaRepository.save(direccion);
    }

    private Pasajero buscarPasajero(Long idUsuario) {
        return pasajeroRepository.findByUsuarioId(idUsuario)
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de pasajero"));
    }

    private DireccionGuardada buscarDelPasajero(Long id, Long idPasajero) {
        DireccionGuardada direccion = direccionGuardadaRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("DireccionGuardada", id));
        if (direccion.getPasajero() == null || !direccion.getPasajero().getId().equals(idPasajero)) {
            throw RecursoNoEncontradoException.de("DireccionGuardada", id);
        }
        return direccion;
    }

    private Point convertirAPunto(String wkt) {
        try {
            Geometry geometria = new WKTReader(FABRICA_GEOMETRIA).read(wkt);
            if (!(geometria instanceof Point punto)) {
                throw new NegocioException("La ubicacion no es un WKT valido de tipo POINT");
            }
            return punto;
        } catch (ParseException excepcion) {
            throw new NegocioException("La ubicacion no es un WKT valido de tipo POINT");
        }
    }

    private DireccionGuardadaResponse aRespuesta(DireccionGuardada direccion) {
        String ubicacionWkt = direccion.getUbicacion() != null ? new WKTWriter().write(direccion.getUbicacion()) : null;
        return new DireccionGuardadaResponse(
                direccion.getId(),
                direccion.getNombre(),
                direccion.getDireccion(),
                ubicacionWkt);
    }
}
