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
import com.taxiuap.backend.sistema.entity.ConfiguracionSistema;
import com.taxiuap.backend.sistema.repository.ConfiguracionSistemaRepository;
import com.taxiuap.backend.trip.enums.TipoEnvio;

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

    @Test
    void sinGuardarElPaqueteCobraLoMismoQueElDelivery() {
        assertEquals(service.actual(), service.paquete());
        assertEquals(service.actual(), service.de(TipoEnvio.ENCOMIENDA));
    }

    @Test
    void elPaqueteGuardadoTieneSuTarifaYNoTocaLaDelDelivery() {
        guardar(TarifaDeliveryService.PAQUETE_TARIFA_BASE, "5");
        guardar(TarifaDeliveryService.PAQUETE_PRECIO_KM, "1.5");

        assertEquals(new TarifaDelivery(new BigDecimal("5.00"), new BigDecimal("1.50")), service.paquete());
        assertEquals(new TarifaDelivery(new BigDecimal("5.00"), new BigDecimal("1.50")), service.de(TipoEnvio.ENCOMIENDA));
        assertEquals(new TarifaDelivery(new BigDecimal("8.00"), new BigDecimal("2.00")), service.actual());
        assertEquals(service.actual(), service.de(TipoEnvio.COMPRA_Y_ENTREGA));
        assertEquals(service.actual(), service.de(null));
    }

    @Test
    void laTarifaDeAntesCobraBaseMasKm() {
        // Solo la usan los pedidos que la guardaron antes de las tablas de precios.
        assertEquals(0, new BigDecimal("8.02").compareTo(
                new TarifaDelivery(new BigDecimal("8.00"), new BigDecimal("2.00")).precioPara(new BigDecimal("0.01"))));
    }

    private void guardar(String clave, String valor) {
        ConfiguracionSistema fila = new ConfiguracionSistema();
        fila.setClave(clave);
        fila.setValor(valor);
        filas.put(clave, fila);
    }
}
