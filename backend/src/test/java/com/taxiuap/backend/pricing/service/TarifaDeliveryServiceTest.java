package com.taxiuap.backend.pricing.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.taxiuap.backend.pricing.dto.TarifaDelivery;
import com.taxiuap.backend.pricing.dto.TarifaDeliveryRequest;
import com.taxiuap.backend.sistema.entity.ConfiguracionSistema;
import com.taxiuap.backend.sistema.repository.ConfiguracionSistemaRepository;

class TarifaDeliveryServiceTest {

    private final Map<String, ConfiguracionSistema> filas = new HashMap<>();
    private TarifaDeliveryService service;

    @BeforeEach
    void preparar() {
        ConfiguracionSistemaRepository repositorio = mock(ConfiguracionSistemaRepository.class);
        when(repositorio.findByClave(any())).thenAnswer(i -> Optional.ofNullable(filas.get(i.<String>getArgument(0))));
        when(repositorio.save(any())).thenAnswer(i -> {
            ConfiguracionSistema fila = i.getArgument(0);
            filas.put(fila.getClave(), fila);
            return fila;
        });
        service = new TarifaDeliveryService(repositorio, new BigDecimal("8"), new BigDecimal("2"));
    }

    @Test
    void sinGuardarValeLaInicial() {
        assertEquals(new TarifaDelivery(new BigDecimal("8.00"), new BigDecimal("2.00")), service.actual());
    }

    @Test
    void elAdministradorLaCambiaYQuedaGuardada() {
        service.guardar(new TarifaDeliveryRequest(new BigDecimal("10"), new BigDecimal("2.5")));

        assertEquals(new TarifaDelivery(new BigDecimal("10.00"), new BigDecimal("2.50")), service.actual());
        assertEquals("10.00", filas.get(TarifaDeliveryService.TARIFA_BASE).getValor());
    }

    @Test
    void unValorRotoONegativoEnLaBdNoSeUsa() {
        ConfiguracionSistema rota = new ConfiguracionSistema();
        rota.setClave(TarifaDeliveryService.TARIFA_BASE);
        rota.setValor("-3");
        filas.put(rota.getClave(), rota);
        ConfiguracionSistema texto = new ConfiguracionSistema();
        texto.setClave(TarifaDeliveryService.PRECIO_KM);
        texto.setValor("abc");
        filas.put(texto.getClave(), texto);

        assertEquals(new TarifaDelivery(new BigDecimal("8.00"), new BigDecimal("2.00")), service.actual());
    }
}
