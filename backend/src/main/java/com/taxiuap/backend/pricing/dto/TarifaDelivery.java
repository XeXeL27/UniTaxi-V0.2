package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;

/**
 * Tarifa de antes de las tablas de precios (paquete y delivery): precio del servicio = tarifaBase +
 * precioKm por cada km por calles. Solo la usan los pedidos que la guardaron al pedirse
 * (datos_entrega.tarifa_base_aplicada y precio_km_aplicado); los nuevos usan la tabla de su servicio.
 */
public record TarifaDelivery(BigDecimal tarifaBase, BigDecimal precioKm) implements TarifaPorDistancia {

    @Override
    public BigDecimal precioPara(BigDecimal distanciaKm) {
        BigDecimal km = distanciaKm == null ? BigDecimal.ZERO : distanciaKm;
        return tarifaBase.add(precioKm.multiply(km));
    }
}
