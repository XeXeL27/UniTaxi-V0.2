package com.taxiuap.backend.trip.enums;

/** Que parte del historial de viajes completados se consulta desde la app. */
public enum PeriodoHistorial {
    /** Los ultimos 10 viajes completados. */
    RECIENTES,
    /** Los del mes en curso, paginados. */
    MES_ACTUAL,
    /** Los del mes pasado, paginados. */
    MES_ANTERIOR
}
