package com.taxiuap.backend.trip.enums;

/**
 * Por que el repartidor no pudo entregar el pedido. El texto acompana al mensaje que escribe el
 * repartidor en el reporte que revisa el administrador.
 */
public enum MotivoFallaEntrega {
    NO_RECIBIO("El cliente no recibió el pedido"),
    NO_PAGO("El cliente no pagó"),
    NO_APROBO_COSTO("El cliente no aceptó el costo total"),
    OTRO("Otro motivo");

    private final String texto;

    MotivoFallaEntrega(String texto) {
        this.texto = texto;
    }

    public String texto() {
        return texto;
    }
}
