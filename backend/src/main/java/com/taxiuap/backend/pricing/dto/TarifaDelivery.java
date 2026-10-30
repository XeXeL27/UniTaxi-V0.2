package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;

/**
 * Tarifa del servicio DELIVERY (encomienda y compra): precio del servicio = tarifaBase + precioKm por
 * cada km por calles. Cada pedido guarda la que valia al pedirlo (datos_entrega.tarifa_base_aplicada y
 * precio_km_aplicado), asi un cambio del administrador vale solo para los pedidos nuevos.
 */
public record TarifaDelivery(BigDecimal tarifaBase, BigDecimal precioKm) {
}
