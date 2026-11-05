package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;

/**
 * Lo que cobra un servicio segun los km por calles. Los pedidos nuevos usan la tabla de tramos de su
 * servicio ({@link ParametrosPrecio}, Bs enteros); los paquetes y compras pedidos antes de las tablas
 * siguen con su tarifa base + precio por km ({@link TarifaDelivery}).
 */
public interface TarifaPorDistancia {

    /** Precio del servicio para [distanciaKm], sin redondear a centavos. */
    BigDecimal precioPara(BigDecimal distanciaKm);
}
