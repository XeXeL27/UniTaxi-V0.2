package com.taxiuap.backend.pricing.enums;

import com.taxiuap.backend.trip.enums.TipoEnvio;

/**
 * Servicio con su propia tabla de precios por km (Tarifas en el panel): el moto taxi, el paquete (la
 * encomienda) y el delivery (la compra). Cada uno tiene su precio base (hasta kmBase) y sus tramos de km
 * extra en tramo_precio. Las claves de configuracion_sistema son las de su base.
 */
public enum ServicioPrecio {
    TAXI("viaje.precio-base", "viaje.km-base", "Moto taxi"),
    PAQUETE("paquete.precio-base", "paquete.km-base", "Paquete"),
    DELIVERY("delivery.precio-base", "delivery.km-base", "Delivery");

    private final String clavePrecioBase;
    private final String claveKmBase;
    private final String nombre;

    ServicioPrecio(String clavePrecioBase, String claveKmBase, String nombre) {
        this.clavePrecioBase = clavePrecioBase;
        this.claveKmBase = claveKmBase;
        this.nombre = nombre;
    }

    public String clavePrecioBase() {
        return clavePrecioBase;
    }

    public String claveKmBase() {
        return claveKmBase;
    }

    public String nombre() {
        return nombre;
    }

    /** La tabla de cada tipo de pedido: el paquete la suya y la compra la del delivery. */
    public static ServicioPrecio de(TipoEnvio tipo) {
        return tipo == TipoEnvio.ENCOMIENDA ? PAQUETE : DELIVERY;
    }
}
