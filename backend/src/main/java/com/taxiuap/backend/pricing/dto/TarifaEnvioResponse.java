package com.taxiuap.backend.pricing.dto;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

import com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryService;

/**
 * Tabla de precios del paquete o del delivery para el formulario del pedido: precio base, km que cubre,
 * tramos y el texto para mostrarla. tarifaBase y precioKm quedan para las apps de antes (mostraban
 * "base + por km"): el precio base y el costo por km del primer tramo.
 */
public record TarifaEnvioResponse(
        BigDecimal tarifaBase,
        BigDecimal precioKm,
        BigDecimal precioBase,
        BigDecimal kmBase,
        List<ParametrosPrecio.Tramo> tramos,
        String texto) {

    public static TarifaEnvioResponse de(ParametrosPrecio tabla) {
        List<ParametrosPrecio.Tramo> tramos = tabla.tramos() == null ? List.of() : tabla.tramos();
        BigDecimal porKm = tramos.isEmpty() || tramos.getFirst().kmAdicional().signum() <= 0
                ? BigDecimal.ZERO.setScale(2)
                : tramos.getFirst().costoAdicional().divide(tramos.getFirst().kmAdicional(), 2, RoundingMode.HALF_UP);
        return new TarifaEnvioResponse(tabla.precioBase(), porKm, tabla.precioBase(), tabla.kmBase(), tramos,
                CalculoPrecioDeliveryService.textoDe(tabla));
    }
}
