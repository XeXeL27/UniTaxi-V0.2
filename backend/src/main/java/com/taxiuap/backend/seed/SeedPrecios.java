package com.taxiuap.backend.seed;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import org.springframework.stereotype.Component;

import com.taxiuap.backend.location.entity.Zona;
import com.taxiuap.backend.pricing.entity.Descuento;
import com.taxiuap.backend.pricing.entity.ReglaDescuentoEstudiantil;
import com.taxiuap.backend.pricing.entity.Tarifa;
import com.taxiuap.backend.pricing.repository.DescuentoRepository;
import com.taxiuap.backend.pricing.repository.ReglaDescuentoEstudiantilRepository;
import com.taxiuap.backend.pricing.repository.TarifaRepository;
import com.taxiuap.backend.seed.SeedCatalogos.CatalogosSembrados;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Siembra las tarifas vigentes por categoria de servicio y zona, la regla de descuento
 * estudiantil y los cupones de descuento de prueba.
 */
@Component
@RequiredArgsConstructor
@Slf4j
class SeedPrecios {

    private final TarifaRepository tarifaRepository;
    private final ReglaDescuentoEstudiantilRepository reglaDescuentoEstudiantilRepository;
    private final DescuentoRepository descuentoRepository;

    /** Resultado de la siembra de precios, usado por el bloque de viajes historicos. */
    record PreciosSembrados(
            Tarifa tarifaSedanEstandarCentro,
            Tarifa tarifaSedanEjecutivoCentro,
            Tarifa tarifaMotoCentro,
            ReglaDescuentoEstudiantil reglaDescuentoSedanUniversidad,
            List<Descuento> descuentos) {
    }

    PreciosSembrados sembrar(CatalogosSembrados catalogos) {
        log.info("Sembrando tarifas, reglas de descuento estudiantil y cupones...");

        Zona centro = catalogos.zonaCentro();
        Zona periferia = catalogos.zonaPeriferia();

        Tarifa tarifaSedanEstandarCentro = crearTarifa(catalogos.sedanEstandar(), centro,
                "6.00", "2.50", "0.30");
        crearTarifa(catalogos.sedanEstandar(), periferia, "7.00", "2.80", "0.35");

        Tarifa tarifaSedanEjecutivoCentro = crearTarifa(catalogos.sedanEjecutivo(), centro,
                "9.00", "3.50", "0.40");
        crearTarifa(catalogos.sedanEjecutivo(), periferia, "10.00", "3.80", "0.45");

        Tarifa tarifaMotoCentro = crearTarifa(catalogos.motoCategoria(), centro, "4.00", "1.80", "0.20");
        crearTarifa(catalogos.motoCategoria(), periferia, "4.50", "2.00", "0.25");

        ReglaDescuentoEstudiantil regla = new ReglaDescuentoEstudiantil();
        regla.setTipoInstitucion(catalogos.universidad());
        regla.setTipoVehiculo(catalogos.sedan());
        regla.setPorcentaje(new BigDecimal("20.00"));
        regla.setMontoMaximo(new BigDecimal("5.00"));
        regla.setViajesMaximosDia(4);
        regla.setVigenteDesde(LocalDate.now().minusMonths(6));
        regla = reglaDescuentoEstudiantilRepository.save(regla);

        List<Descuento> descuentos = List.of(
                crearDescuento("BIENVENIDA10", "10% de descuento en tu primer viaje", "10.00", "5.00", 100,
                        LocalDate.now().minusMonths(1), LocalDate.now().plusMonths(2)),
                crearDescuento("VERANO15", "15% de descuento por temporada", "15.00", "8.00", 50,
                        LocalDate.now().minusDays(10), LocalDate.now().plusMonths(1)),
                crearDescuento("PROMO2024", "Promocion de fin de anio 2024 (vencida)", "20.00", "10.00", 200,
                        LocalDate.now().minusMonths(8), LocalDate.now().minusDays(30)));

        log.info("Precios sembrados: 6 tarifas, 1 regla de descuento estudiantil, {} cupones", descuentos.size());

        return new PreciosSembrados(tarifaSedanEstandarCentro, tarifaSedanEjecutivoCentro, tarifaMotoCentro,
                regla, descuentos);
    }

    private Tarifa crearTarifa(CategoriaServicio categoriaServicio, Zona zona,
            String tarifaBase, String precioKm, String precioMinuto) {
        Tarifa tarifa = new Tarifa();
        tarifa.setCategoriaServicio(categoriaServicio);
        tarifa.setZona(zona);
        tarifa.setTarifaBase(new BigDecimal(tarifaBase));
        tarifa.setPrecioKm(new BigDecimal(precioKm));
        tarifa.setPrecioMinuto(new BigDecimal(precioMinuto));
        tarifa.setTarifaMinima(new BigDecimal(tarifaBase));
        tarifa.setVigenteDesde(LocalDate.now().minusMonths(6));
        return tarifaRepository.save(tarifa);
    }

    private Descuento crearDescuento(String codigo, String descripcion, String porcentaje, String montoMaximo,
            int usosMaximos, LocalDate vigenteDesde, LocalDate vigenteHasta) {
        Descuento descuento = new Descuento();
        descuento.setCodigo(codigo);
        descuento.setDescripcion(descripcion);
        descuento.setPorcentaje(new BigDecimal(porcentaje));
        descuento.setMontoMaximo(new BigDecimal(montoMaximo));
        descuento.setUsosMaximos(usosMaximos);
        descuento.setVigenteDesde(vigenteDesde);
        descuento.setVigenteHasta(vigenteHasta);
        return descuentoRepository.save(descuento);
    }
}
