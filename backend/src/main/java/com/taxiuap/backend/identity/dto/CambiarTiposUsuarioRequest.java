package com.taxiuap.backend.identity.dto;

import java.math.BigDecimal;
import java.util.List;

import com.taxiuap.backend.identity.enums.TipoRegistroUsuario;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

/**
 * Tipos de usuario que la persona debe tener despues del cambio (PASAJERO, CONDUCTOR, DELIVERY, ADMIN).
 * limiteAdelantoCompra solo se usa al pasar a delivery.
 */
public record CambiarTiposUsuarioRequest(
        @NotNull List<TipoRegistroUsuario> tipos,
        @DecimalMin("0") @DecimalMax("100000") BigDecimal limiteAdelantoCompra) {
}
