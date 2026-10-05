package com.taxiuap.backend.seed;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.location.entity.Zona;
import com.taxiuap.backend.location.repository.ZonaRepository;
import com.taxiuap.backend.pricing.entity.Tarifa;
import com.taxiuap.backend.pricing.repository.TarifaRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/** Mantiene una tarifa vigente de referencia para poder persistir viajes DELIVERY. */
@Component
@Order(3)
@RequiredArgsConstructor
@Slf4j
public class SeedTarifaDelivery implements CommandLineRunner {

    private final CategoriaServicioRepository categoriaServicioRepository;
    private final ZonaRepository zonaRepository;
    private final TarifaRepository tarifaRepository;

    @Value("${taxiuap.seed.habilitado:false}")
    private boolean seedHabilitado;

    @Value("${taxiuap.delivery.tarifa-base:4.00}")
    private BigDecimal tarifaBase = new BigDecimal("4.00");

    @Value("${taxiuap.delivery.precio-km:1.80}")
    private BigDecimal precioKm = new BigDecimal("1.80");

    @Value("${taxiuap.delivery.precio-minuto:0.20}")
    private BigDecimal precioMinuto = new BigDecimal("0.20");

    @Override
    @Transactional
    public void run(String... args) {
        if (!seedHabilitado) return;

        Optional<CategoriaServicio> delivery = categoriaServicioRepository.findAll().stream()
                .filter(categoria -> "DELIVERY".equalsIgnoreCase(categoria.getNombre()))
                .filter(categoria -> categoria.getEstadoCategoriaServicio() == EstadoRegistro.A)
                .findFirst();
        Optional<Zona> centro = zonaRepository.findAll().stream()
                .filter(zona -> "Centro".equalsIgnoreCase(zona.getNombre()))
                .filter(zona -> zona.getEstadoZona() == EstadoRegistro.A)
                .findFirst();
        if (delivery.isEmpty() || centro.isEmpty()) return;

        asegurar(delivery.get(), centro.get());
    }

    @Transactional
    public Tarifa asegurar(CategoriaServicio categoria, Zona zona) {
        LocalDate hoy = LocalDate.now();
        Optional<Tarifa> vigente = tarifaRepository.findByCategoriaServicioId(categoria.getId()).stream()
                .filter(tarifa -> tarifa.getEstadoTarifa() == EstadoRegistro.A)
                .filter(tarifa -> tarifa.getVigenteDesde() != null && !tarifa.getVigenteDesde().isAfter(hoy))
                .filter(tarifa -> tarifa.getVigenteHasta() == null || !tarifa.getVigenteHasta().isBefore(hoy))
                .findFirst();
        if (vigente.isPresent()) return vigente.get();

        Tarifa tarifa = new Tarifa();
        tarifa.setCategoriaServicio(categoria);
        tarifa.setZona(zona);
        tarifa.setTarifaBase(tarifaBase);
        tarifa.setPrecioKm(precioKm);
        tarifa.setPrecioMinuto(precioMinuto);
        tarifa.setTarifaMinima(tarifaBase);
        tarifa.setVigenteDesde(hoy.minusMonths(6));
        tarifa.setEstadoTarifa(EstadoRegistro.A);
        Tarifa guardada = tarifaRepository.save(tarifa);
        log.info("Tarifa de referencia DELIVERY disponible para zona {}", zona.getNombre());
        return guardada;
    }
}
