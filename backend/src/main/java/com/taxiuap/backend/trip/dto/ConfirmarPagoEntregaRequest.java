package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

import com.taxiuap.backend.pricing.enums.MetodoPago;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

/**
 * Pago directo que el repartidor recibio del cliente: producto mas servicio. Sin metodo de pago se
 * conserva el que ya tenia el viaje.
 */
public record ConfirmarPagoEntregaRequest(
        @NotNull(message = "Registra cuanto recibiste")
        @DecimalMin(value = "0.00", message = "El monto no puede ser negativo")
        BigDecimal montoRecibido,
        MetodoPago metodoPago) {
}
