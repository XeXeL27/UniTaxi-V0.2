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

    @Test
    void sinGuardarElPaqueteCobraLoMismoQueElDelivery() {
        assertEquals(service.actual(), service.paquete());
        assertEquals(service.actual(), service.de(TipoEnvio.ENCOMIENDA));
    }

    @Test
    void elPaqueteTieneSuTarifaYNoTocaLaDelDelivery() {
        service.guardarPaquete(new TarifaDeliveryRequest(new BigDecimal("5"), new BigDecimal("1.5")));

        assertEquals(new TarifaDelivery(new BigDecimal("5.00"), new BigDecimal("1.50")), service.paquete());
        assertEquals(new TarifaDelivery(new BigDecimal("5.00"), new BigDecimal("1.50")), service.de(TipoEnvio.ENCOMIENDA));
        assertEquals(new TarifaDelivery(new BigDecimal("8.00"), new BigDecimal("2.00")), service.actual());
        assertEquals(service.actual(), service.de(TipoEnvio.COMPRA_Y_ENTREGA));
        // Las apps de antes no mandan el tipo: reciben la del delivery.
        assertEquals(service.actual(), service.de(null));
    }

    @Test
    void cambiarElDeliveryNoLeCambiaElPrecioAlPaquete() {
        service.guardar(new TarifaDeliveryRequest(new BigDecimal("12"), new BigDecimal("3")));

        assertEquals(new TarifaDelivery(new BigDecimal("12.00"), new BigDecimal("3.00")), service.actual());
        // El paquete sigue con lo que cobraba antes del cambio (la tarifa que compartian).
        assertEquals(new TarifaDelivery(new BigDecimal("8.00"), new BigDecimal("2.00")), service.paquete());

        // Y si el paquete ya tenia la suya, guardar el delivery no la pisa.
        service.guardarPaquete(new TarifaDeliveryRequest(new BigDecimal("6"), new BigDecimal("1")));
        service.guardar(new TarifaDeliveryRequest(new BigDecimal("9"), new BigDecimal("2")));
        assertEquals(new TarifaDelivery(new BigDecimal("6.00"), new BigDecimal("1.00")), service.paquete());
    }
}
