package com.taxiuap.backend.identity.enums;

/**
 * Como registra el administrador a una persona desde el panel: EXTERNA (pasajero normal) o
 * ESTUDIANTE_UAP (pasajero con descuento, solo si el SIGSE confirma su RU y sus datos).
 */
public enum TipoRegistroPersona {
    EXTERNA,
    ESTUDIANTE_UAP
}
