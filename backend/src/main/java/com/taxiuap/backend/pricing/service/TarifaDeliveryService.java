package com.taxiuap.backend.pricing.service;

import java.math.BigDecimal;
import java.math.RoundingMode;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.pricing.dto.TarifaDelivery;
import com.taxiuap.backend.pricing.dto.TarifaDeliveryRequest;
import com.taxiuap.backend.sistema.entity.ConfiguracionSistema;
import com.taxiuap.backend.sistema.repository.ConfiguracionSistemaRepository;

import lombok.extern.slf4j.Slf4j;

/**
 * Tarifa del delivery que el administrador cambia en el panel; vale desde el siguiente pedido, sin
 * reiniciar el backend. Va en configuracion_sistema (delivery.tarifa-base y delivery.precio-km). Mientras
 * el administrador no la guarde vale la de taxiuap.delivery.* (8 Bs y 2 Bs por km si no se definen).
 */
@Slf4j
@Service
@Transactional(readOnly = true)
public class TarifaDeliveryService {

    static final String TARIFA_BASE = "delivery.tarifa-base";
    static final String PRECIO_KM = "delivery.precio-km";

    private final ConfiguracionSistemaRepository configuracionRepository;
    private final BigDecimal tarifaBaseInicial;
    private final BigDecimal precioKmInicial;

    public TarifaDeliveryService(ConfiguracionSistemaRepository configuracionRepository,
            @Value("${taxiuap.delivery.tarifa-base:8.00}") BigDecimal tarifaBaseInicial,
            @Value("${taxiuap.delivery.precio-km:2.00}") BigDecimal precioKmInicial) {
        this.configuracionRepository = configuracionRepository;
        this.tarifaBaseInicial = dinero(tarifaBaseInicial);
        this.precioKmInicial = dinero(precioKmInicial);
    }

    public TarifaDelivery actual() {
        return new TarifaDelivery(leer(TARIFA_BASE, tarifaBaseInicial), leer(PRECIO_KM, precioKmInicial));
    }

    @Transactional
    public TarifaDelivery guardar(TarifaDeliveryRequest datos) {
        TarifaDelivery anterior = actual();
        escribir(TARIFA_BASE, dinero(datos.tarifaBase()).toPlainString());
        escribir(PRECIO_KM, dinero(datos.precioKm()).toPlainString());
        TarifaDelivery nueva = actual();
        log.info("Tarifa del delivery cambiada: base {} -> {} Bs, km {} -> {} Bs", anterior.tarifaBase(),
                nueva.tarifaBase(), anterior.precioKm(), nueva.precioKm());
        return nueva;
    }

    private BigDecimal leer(String clave, BigDecimal porDefecto) {
        return configuracionRepository.findByClave(clave)
                .map(ConfiguracionSistema::getValor)
                .filter(valor -> valor != null && !valor.isBlank())
                .map(valor -> {
                    try {
                        BigDecimal leido = new BigDecimal(valor.trim());
                        return leido.signum() < 0 ? porDefecto : dinero(leido);
                    } catch (NumberFormatException e) {
                        return porDefecto;
                    }
                })
                .orElse(porDefecto);
    }

    private void escribir(String clave, String valor) {
        ConfiguracionSistema fila = configuracionRepository.findByClave(clave).orElseGet(() -> {
            ConfiguracionSistema nueva = new ConfiguracionSistema();
            nueva.setClave(clave);
            return nueva;
        });
        fila.setValor(valor);
        configuracionRepository.save(fila);
    }

    private static BigDecimal dinero(BigDecimal valor) {
        return valor.setScale(2, RoundingMode.HALF_UP);
    }
}
