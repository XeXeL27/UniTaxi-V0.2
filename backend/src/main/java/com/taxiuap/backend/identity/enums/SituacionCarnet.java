package com.taxiuap.backend.identity.enums;

/**
 * Revision de los datos del carnet de una persona. OBSERVADO: la persona indico que el sistema leyo
 * mal sus datos (o su nombre parece falso u ofensivo) y un administrador debe revisarlos con las
 * fotos antes de que pueda usar la app. null en las personas de antes: se toman como verificadas.
 */
public enum SituacionCarnet {
    VERIFICADO,
    OBSERVADO
}
