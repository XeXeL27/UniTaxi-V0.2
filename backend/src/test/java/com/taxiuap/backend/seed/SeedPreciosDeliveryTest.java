package com.taxiuap.backend.seed;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;

import com.taxiuap.backend.location.entity.Zona;
import com.taxiuap.backend.location.repository.ZonaRepository;
import com.taxiuap.backend.pricing.entity.Descuento;
import com.taxiuap.backend.pricing.entity.ReglaDescuentoEstudiantil;
import com.taxiuap.backend.pricing.entity.Tarifa;
import com.taxiuap.backend.pricing.repository.DescuentoRepository;
import com.taxiuap.backend.pricing.repository.ReglaDescuentoEstudiantilRepository;
import com.taxiuap.backend.pricing.repository.TarifaRepository;
import com.taxiuap.backend.seed.SeedCatalogos.CatalogosSembrados;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;

class SeedPreciosDeliveryTest {

    @Test
    void siembraTarifaDeReferenciaParaCategoriaDelivery() {
        TarifaRepository tarifaRepository = Mockito.mock(TarifaRepository.class);
        ReglaDescuentoEstudiantilRepository reglaRepository = Mockito.mock(ReglaDescuentoEstudiantilRepository.class);
        DescuentoRepository descuentoRepository = Mockito.mock(DescuentoRepository.class);
        CategoriaServicio delivery = new CategoriaServicio();
        delivery.setId(7);
        delivery.setNombre("DELIVERY");
        List<Tarifa> tarifasDeliveryGuardadas = new ArrayList<>();
        when(tarifaRepository.findByCategoriaServicioId(7))
                .thenAnswer(invocacion -> new ArrayList<>(tarifasDeliveryGuardadas));
        when(tarifaRepository.save(any(Tarifa.class))).thenAnswer(invocacion -> {
            Tarifa tarifa = invocacion.getArgument(0);
            if (tarifa.getCategoriaServicio() == delivery) tarifasDeliveryGuardadas.add(tarifa);
            return tarifa;
        });
        when(reglaRepository.save(any(ReglaDescuentoEstudiantil.class)))
                .thenAnswer(invocacion -> invocacion.getArgument(0));
        when(descuentoRepository.save(any(Descuento.class))).thenAnswer(invocacion -> invocacion.getArgument(0));

        Zona centro = new Zona();
        centro.setId(1);
        Zona periferia = new Zona();
        periferia.setId(2);
        CatalogosSembrados catalogos = new CatalogosSembrados(null, null, List.of(), null, null, null,
                new CategoriaServicio(), new CategoriaServicio(), new CategoriaServicio(), delivery,
                List.of(centro, periferia), List.of());
        SeedTarifaDelivery seedTarifaDelivery = new SeedTarifaDelivery(
                Mockito.mock(CategoriaServicioRepository.class), Mockito.mock(ZonaRepository.class), tarifaRepository);
        SeedPrecios seed = new SeedPrecios(tarifaRepository, reglaRepository, descuentoRepository, seedTarifaDelivery);

        seed.sembrar(catalogos);
        seed.sembrar(catalogos);

        ArgumentCaptor<Tarifa> tarifas = ArgumentCaptor.forClass(Tarifa.class);
        Mockito.verify(tarifaRepository, Mockito.atLeastOnce()).save(tarifas.capture());
        assertTrue(tarifas.getAllValues().stream().anyMatch(tarifa -> tarifa.getCategoriaServicio() == delivery));
        org.junit.jupiter.api.Assertions.assertEquals(1, tarifasDeliveryGuardadas.size());
        Tarifa deliveryTarifa = tarifasDeliveryGuardadas.get(0);
        org.junit.jupiter.api.Assertions.assertEquals(new java.math.BigDecimal("8.00"), deliveryTarifa.getTarifaBase());
        org.junit.jupiter.api.Assertions.assertEquals(new java.math.BigDecimal("2.00"), deliveryTarifa.getPrecioKm());
        org.junit.jupiter.api.Assertions.assertEquals(java.math.BigDecimal.ZERO, deliveryTarifa.getPrecioMinuto());
    }

    @Test
    void mantieneLaTarifaAdministradaDeDeliveryEnOtraZonaSinDuplicarEnCentro() {
        TarifaRepository tarifaRepository = Mockito.mock(TarifaRepository.class);
        CategoriaServicioRepository categoriaRepository = Mockito.mock(CategoriaServicioRepository.class);
        ZonaRepository zonaRepository = Mockito.mock(ZonaRepository.class);
        CategoriaServicio delivery = new CategoriaServicio();
        delivery.setId(7);
        delivery.setNombre("DELIVERY");
        Zona periferia = new Zona();
        periferia.setId(2);
        Tarifa administrada = new Tarifa();
        administrada.setCategoriaServicio(delivery);
        administrada.setZona(periferia);
        administrada.setTarifaBase(new java.math.BigDecimal("8.00"));
        administrada.setPrecioKm(new java.math.BigDecimal("2.00"));
        administrada.setPrecioMinuto(java.math.BigDecimal.ZERO);
        administrada.setVigenteDesde(java.time.LocalDate.now().minusMonths(1));
        administrada.setEstadoTarifa(com.taxiuap.backend.shared.enums.EstadoRegistro.A);
        when(tarifaRepository.findByCategoriaServicioId(7)).thenReturn(List.of(administrada));
        SeedTarifaDelivery seeder = new SeedTarifaDelivery(categoriaRepository, zonaRepository, tarifaRepository);

        Tarifa resultado = seeder.asegurar(delivery, new Zona());

        assertTrue(resultado == administrada);
        verify(tarifaRepository, never()).save(any(Tarifa.class));
    }
}
