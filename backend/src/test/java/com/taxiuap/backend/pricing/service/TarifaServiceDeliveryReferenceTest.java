package com.taxiuap.backend.pricing.service;

import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import com.taxiuap.backend.pricing.entity.Tarifa;
import com.taxiuap.backend.pricing.repository.TarifaRepository;
import com.taxiuap.backend.location.repository.ZonaRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;

class TarifaServiceDeliveryReferenceTest {

    @Test
    void referenciaTecnicaSinZonaNoRompeLaConsultaAdministrativa() {
        TarifaRepository tarifas = Mockito.mock(TarifaRepository.class);
        CategoriaServicioRepository categorias = Mockito.mock(CategoriaServicioRepository.class);
        ZonaRepository zonas = Mockito.mock(ZonaRepository.class);
        CategoriaServicio delivery = new CategoriaServicio();
        delivery.setId(7);
        delivery.setNombre("DELIVERY");
        Tarifa referencia = new Tarifa();
        referencia.setId(90L);
        referencia.setCategoriaServicio(delivery);
        referencia.setTarifaBase(new BigDecimal("4.00"));
        referencia.setPrecioKm(new BigDecimal("1.80"));
        referencia.setPrecioMinuto(new BigDecimal("0.20"));
        referencia.setTarifaMinima(new BigDecimal("4.00"));
        referencia.setVigenteDesde(LocalDate.now().minusMonths(6));
        referencia.setEstadoTarifa(EstadoRegistro.A);
        when(tarifas.findAll()).thenReturn(List.of(referencia));
        when(tarifas.findById(90L)).thenReturn(Optional.of(referencia));
        TarifaService service = new TarifaService(tarifas, categorias, zonas);

        assertTrue(service.listar(null, 7, false).isEmpty());
        assertNull(service.buscarPorId(90L).idZona());
        assertNull(service.buscarPorId(90L).nombreZona());
    }
}
