package com.taxiuap.backend.seed;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
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
        when(tarifaRepository.findByCategoriaServicioIdAndZonaId(7, 1))
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
    }
}
