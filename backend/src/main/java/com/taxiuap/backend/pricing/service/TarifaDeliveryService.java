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
import com.taxiuap.backend.trip.enums.TipoEnvio;

import lombok.extern.slf4j.Slf4j;

/**
 * Tarifas del delivery (la compra) y del paquete (la encomienda) que el administrador cambia en el panel;
 * valen desde el siguiente pedido, sin reiniciar el backend. Van en configuracion_sistema
 * (delivery.tarifa-base / delivery.precio-km y paquete.tarifa-base / paquete.precio-km). Mientras el
 * administrador no guarde la del delivery vale la de taxiuap.delivery.* (8 Bs y 2 Bs por km si no se
 * definen); mientras no guarde la del paquete, el paquete cobra lo mismo que el delivery (antes las dos
 * eran una sola tarifa: al actualizar nada cambia).
 */
@Slf4j
@Service
@Transactional(readOnly = true)
public class TarifaDeliveryService {

    static final String TARIFA_BASE = "delivery.tarifa-base";
    static final String PRECIO_KM = "delivery.precio-km";
    static final String PAQUETE_TARIFA_BASE = "paquete.tarifa-base";
    static final String PAQUETE_PRECIO_KM = "paquete.precio-km";

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

    /** Tarifa del delivery (la compra). */
    public TarifaDelivery actual() {
        return new TarifaDelivery(leer(TARIFA_BASE, tarifaBaseInicial), leer(PRECIO_KM, precioKmInicial));
    }

    /** Tarifa del paquete (la encomienda); sin guardar, la misma del delivery. */
    public TarifaDelivery paquete() {
        TarifaDelivery delivery = actual();
        return new TarifaDelivery(leer(PAQUETE_TARIFA_BASE, delivery.tarifaBase()),
                leer(PAQUETE_PRECIO_KM, delivery.precioKm()));
    }

    /** La tarifa de cada tipo de pedido: el paquete la suya y la compra la del delivery. */
    public TarifaDelivery de(TipoEnvio tipo) {
        return tipo == TipoEnvio.ENCOMIENDA ? paquete() : actual();
    }

    @Transactional
    public TarifaDelivery guardar(TarifaDeliveryRequest datos) {
        TarifaDelivery anterior = actual();
        // El paquete que todavia no tiene tarifa propia cobraba lo mismo que el delivery: se le fija esa
        // antes del cambio, asi cambiar el delivery no le cambia el precio al paquete.
        if (sinGuardar(PAQUETE_TARIFA_BASE) && sinGuardar(PAQUETE_PRECIO_KM)) {
            escribir(PAQUETE_TARIFA_BASE, anterior.tarifaBase().toPlainString());
            escribir(PAQUETE_PRECIO_KM, anterior.precioKm().toPlainString());
        }
        escribir(TARIFA_BASE, dinero(datos.tarifaBase()).toPlainString());
        escribir(PRECIO_KM, dinero(datos.precioKm()).toPlainString());
        TarifaDelivery nueva = actual();
        log.info("Tarifa del delivery cambiada: base {} -> {} Bs, km {} -> {} Bs", anterior.tarifaBase(),
                nueva.tarifaBase(), anterior.precioKm(), nueva.precioKm());
        return nueva;
    }

    @Transactional
    public TarifaDelivery guardarPaquete(TarifaDeliveryRequest datos) {
        TarifaDelivery anterior = paquete();
        escribir(PAQUETE_TARIFA_BASE, dinero(datos.tarifaBase()).toPlainString());
        escribir(PAQUETE_PRECIO_KM, dinero(datos.precioKm()).toPlainString());
        TarifaDelivery nueva = paquete();
        log.info("Tarifa del paquete cambiada: base {} -> {} Bs, km {} -> {} Bs", anterior.tarifaBase(),
                nueva.tarifaBase(), anterior.precioKm(), nueva.precioKm());
        return nueva;
    }

    private boolean sinGuardar(String clave) {
        return configuracionRepository.findByClave(clave)
                .map(ConfiguracionSistema::getValor)
                .map(valor -> valor == null || valor.isBlank())
                .orElse(true);
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
