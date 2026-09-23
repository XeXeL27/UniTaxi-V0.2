package com.taxiuap.backend.location.service;

import java.util.List;

import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Polygon;
import org.locationtech.jts.geom.PrecisionModel;
import org.locationtech.jts.io.ParseException;
import org.locationtech.jts.io.WKTReader;
import org.locationtech.jts.io.WKTWriter;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.location.dto.ZonaRequest;
import com.taxiuap.backend.location.dto.ZonaResponse;
import com.taxiuap.backend.location.entity.Zona;
import com.taxiuap.backend.location.repository.ZonaRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/** CRUD administrativo de zonas geograficas de cobertura, con borrado logico. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ZonaService {

    private static final int SRID_WGS84 = 4326;
    private static final GeometryFactory FABRICA_GEOMETRIA =
            new GeometryFactory(new PrecisionModel(), SRID_WGS84);

    private final ZonaRepository zonaRepository;

    public List<ZonaResponse> listar(boolean incluirInactivos) {
        return zonaRepository.findAll().stream()
                .filter(zona -> incluirInactivos || zona.getEstadoZona() == EstadoRegistro.A)
                .map(this::aResponse)
                .toList();
    }

    public ZonaResponse buscarPorId(Integer id) {
        return aResponse(obtenerZona(id));
    }

    @Transactional
    public ZonaResponse crear(ZonaRequest request) {
        Zona zona = new Zona();
        zona.setNombre(request.nombre());
        zona.setPoligono(convertirAPoligono(request.poligonoWkt()));
        zona.setEstadoZona(EstadoRegistro.A);
        return aResponse(zonaRepository.save(zona));
    }

    @Transactional
    public ZonaResponse actualizar(Integer id, ZonaRequest request) {
        Zona zona = obtenerZona(id);
        zona.setNombre(request.nombre());
        zona.setPoligono(convertirAPoligono(request.poligonoWkt()));
        return aResponse(zonaRepository.save(zona));
    }

    @Transactional
    public void eliminar(Integer id) {
        Zona zona = obtenerZona(id);
        zona.setEstadoZona(EstadoRegistro.X);
        zonaRepository.save(zona);
    }

    private Zona obtenerZona(Integer id) {
        return zonaRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Zona", id));
    }

    private Polygon convertirAPoligono(String wkt) {
        try {
            Geometry geometria = new WKTReader(FABRICA_GEOMETRIA).read(wkt);
            if (!(geometria instanceof Polygon poligono)) {
                throw new NegocioException("El poligono no es un WKT valido de tipo POLYGON");
            }
            return poligono;
        } catch (ParseException excepcion) {
            throw new NegocioException("El poligono no es un WKT valido de tipo POLYGON");
        }
    }

    private ZonaResponse aResponse(Zona zona) {
        String poligonoWkt = zona.getPoligono() != null ? new WKTWriter().write(zona.getPoligono()) : null;
        return new ZonaResponse(zona.getId(), zona.getNombre(), poligonoWkt);
    }
}
