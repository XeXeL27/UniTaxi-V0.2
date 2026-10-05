package com.taxiuap.backend.vehicle.entity;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class CategoriaServicioEntregaTest {

    @Test
    void deliverySoloEsCompatibleConMoto() {
        TipoVehiculo moto = new TipoVehiculo();
        moto.setCodigo("MOTO");
        TipoVehiculo sedan = new TipoVehiculo();
        sedan.setCodigo("SEDAN");

        CategoriaServicio delivery = new CategoriaServicio();
        delivery.setNombre("DELIVERY");
        delivery.setTipoVehiculo(moto);

        CategoriaServicio deliveryEnSedan = new CategoriaServicio();
        deliveryEnSedan.setNombre("DELIVERY");
        deliveryEnSedan.setTipoVehiculo(sedan);

        assertTrue(delivery.esDeliveryCompatible());
        assertFalse(deliveryEnSedan.esDeliveryCompatible());
    }
}
