package com.taxiuap.backend.identity.dto;

import java.math.BigDecimal;
import java.util.List;

/**
 * Tipos de usuario de una persona (PASAJERO, CONDUCTOR de taxi, DELIVERY, ADMIN) y, si tiene cuenta de
 * conductor, cuanto puede adelantar en una compra. Para la ficha de Personas del panel.
 */
public record TiposPersonaResponse(List<String> tipos, BigDecimal limiteAdelantoCompra) {
}
