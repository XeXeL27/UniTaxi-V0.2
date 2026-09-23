package com.taxiuap.backend.seed;

import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Polygon;
import org.locationtech.jts.geom.PrecisionModel;

/**
 * Utilidades geometricas para el seed: construye puntos y poligonos JTS con SRID 4326 sobre
 * coordenadas reales de Cobija, Pando (aprox. latitud -11.02, longitud -68.76).
 *
 * OJO: en WKT (y en JTS Coordinate) el orden es (longitud, latitud), no (latitud, longitud).
 * Es un error clasico invertirlo: POINT(-68.76 -11.02) es correcto, POINT(-11.02 -68.76) no.
 */
final class GeometriaSeed {

    private static final int SRID_WGS84 = 4326;
    private static final GeometryFactory FABRICA = new GeometryFactory(new PrecisionModel(), SRID_WGS84);

    /** Centro aproximado de Cobija, usado como referencia para desplazar el resto de puntos. */
    static final double LONGITUD_CENTRO_COBIJA = -68.76;
    static final double LATITUD_CENTRO_COBIJA = -11.02;

    private GeometriaSeed() {
    }

    /** Crea un punto geografico. Recuerda: el orden es (longitud, latitud). */
    static Point punto(double longitud, double latitud) {
        return FABRICA.createPoint(new Coordinate(longitud, latitud));
    }

    /** Poligono rectangular simple usado para las zonas de cobertura de prueba. */
    static Polygon poligonoRectangulo(double lonMin, double latMin, double lonMax, double latMax) {
        Coordinate[] anillo = new Coordinate[] {
                new Coordinate(lonMin, latMin),
                new Coordinate(lonMax, latMin),
                new Coordinate(lonMax, latMax),
                new Coordinate(lonMin, latMax),
                new Coordinate(lonMin, latMin)
        };
        return FABRICA.createPolygon(anillo);
    }
}
