package com.taxiuap.backend.trip.enums;

/**
 * Costo total de una compra presentado al cliente. Solo una propuesta esta vigente (PENDIENTE o
 * ACEPTADA); si el repartidor corrige los precios, la vigente pasa a REEMPLAZADA y se pide aceptar la
 * nueva version.
 */
public enum SituacionPropuestaCosto {
    PENDIENTE,
    ACEPTADA,
    REEMPLAZADA
}
