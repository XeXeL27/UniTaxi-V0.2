package com.taxiuap.backend.trip.service;

import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.locationtech.jts.io.ParseException;
import org.locationtech.jts.io.WKTReader;

import com.taxiuap.backend.shared.exception.NegocioException;

/**
 * Conversion de las coordenadas que llegan como texto WKT (la app las manda asi) al punto geografico que
 * espera la columna geography(Point,4326). Vive aparte porque la usan tanto la solicitud del pasajero
 * como las acciones de entrega del repartidor, que tambien mandan el punto del comercio.
 */
public final class PuntoDesdeWkt {

    private static final int SRID_WGS84 = 4326;
    private static final GeometryFactory FABRICA_GEOMETRIA =
            new GeometryFactory(new PrecisionModel(), SRID_WGS84);

    private PuntoDesdeWkt() {
    }

    public static Point convertir(String wkt) {
        if (wkt == null || wkt.isBlank()) {
            throw new NegocioException("La ubicacion no es un WKT valido de tipo POINT");
        }
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

    /** Punto desde el GPS del telefono (latitud y longitud), o null si no llego. */
    public static Point desdeCoordenadas(Double latitud, Double longitud) {
        if (latitud == null || longitud == null) {
            return null;
        }
        return FABRICA_GEOMETRIA.createPoint(new Coordinate(longitud, latitud));
    }
}
