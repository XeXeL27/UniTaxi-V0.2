package com.taxiuap.backend.pricing.service;

import org.locationtech.jts.geom.Point;

import com.taxiuap.backend.pricing.dto.RutaResponse;

/** Cliente de un proveedor de rutas por calles. */
@FunctionalInterface
public interface ClienteRutas {

    RutaResponse calcular(Point origen, Point destino);
}
