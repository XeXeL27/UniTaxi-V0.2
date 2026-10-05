package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

/**
 * Precio del viaje en taxi (Tarifas > Precio del viaje): precioBase cubre los primeros kmBase y cada
 * tramo activo, en orden, suma sus km y su costo. Ejemplo: base 5 km = 8 Bs, tramos +3 km +2 Bs y
 * +3 km +2 Bs -> hasta 5 km = 8 Bs, de 5 a 8 km = 10 Bs, de 8 a 11 km = 12 Bs. Si el viaje pasa del
 * ultimo tramo, ese ultimo tramo se repite (11 a 14 km = 14 Bs...).
 *
 * descuentoEstudiante (Tarifas > Descuento estudiante): Bs enteros que se restan al estudiante con
 * matricula vigente. viajesEstudiantePorDia: viajes con descuento por dia (null: sin limite).
 */
public record ParametrosPrecio(
        BigDecimal precioBase,
        BigDecimal kmBase,
        List<Tramo> tramos,
        Integer descuentoEstudiante,
        Integer viajesEstudiantePorDia) {

    /** Un tramo activo; id null en los que no salen de la BD. */
    public record Tramo(Integer id, BigDecimal kmAdicional, BigDecimal costoAdicional, Integer orden) {
    }

    /** Precio normal (sin descuento) de un viaje de [distanciaKm]. */
    public BigDecimal precioPara(BigDecimal distanciaKm) {
        BigDecimal km = distanciaKm == null ? BigDecimal.ZERO : distanciaKm.setScale(2, RoundingMode.HALF_UP);
        BigDecimal hasta = kmBase;
        BigDecimal precio = precioBase;
        if (km.compareTo(hasta) <= 0 || tramos == null || tramos.isEmpty()) {
            return precio.setScale(2, RoundingMode.HALF_UP);
        }
        for (Tramo tramo : tramos) {
            hasta = hasta.add(tramo.kmAdicional());
            precio = precio.add(tramo.costoAdicional());
            if (km.compareTo(hasta) <= 0) return precio.setScale(2, RoundingMode.HALF_UP);
        }
        // Mas alla del ultimo tramo: se repite el ultimo tantas veces como haga falta (tramo empezado se cobra).
        Tramo ultimo = tramos.getLast();
        BigDecimal repeticiones = km.subtract(hasta).divide(ultimo.kmAdicional(), 0, RoundingMode.CEILING);
        return precio.add(ultimo.costoAdicional().multiply(repeticiones)).setScale(2, RoundingMode.HALF_UP);
    }
}
