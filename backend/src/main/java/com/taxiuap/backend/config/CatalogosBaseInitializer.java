package com.taxiuap.backend.config;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Polygon;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.institution.entity.Institucion;
import com.taxiuap.backend.institution.entity.TipoInstitucion;
import com.taxiuap.backend.institution.repository.InstitucionRepository;
import com.taxiuap.backend.institution.repository.TipoInstitucionRepository;
import com.taxiuap.backend.location.entity.Zona;
import com.taxiuap.backend.location.repository.ZonaRepository;
import com.taxiuap.backend.pricing.entity.Tarifa;
import com.taxiuap.backend.pricing.repository.TarifaRepository;
import com.taxiuap.backend.rating.entity.EtiquetaCalificacion;
import com.taxiuap.backend.rating.enums.AplicaA;
import com.taxiuap.backend.rating.enums.TipoEtiqueta;
import com.taxiuap.backend.rating.repository.EtiquetaCalificacionRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Catalogos minimos para operar en una BD nueva (produccion, sin el seed de prueba): tipos de
 * institucion y la UAP, tipos de vehiculo, categorias de servicio (ESTANDAR, EJECUTIVO, MOTO y
 * DELIVERY), etiquetas de calificacion, las zonas de Cobija y una tarifa vigente por categoria (el
 * viaje la guarda como referencia; el precio del taxi sale de los tramos de km).
 *
 * Solo crea lo que falta: en una BD que ya tiene datos no hace nada. Corre despues de DataSeeder
 * (@Order) para no duplicar lo que el seed de prueba siembra en una BD vacia.
 */
@Component
@Order(6)
@RequiredArgsConstructor
@Slf4j
public class CatalogosBaseInitializer implements ApplicationRunner {

    private static final GeometryFactory FABRICA = new GeometryFactory(new PrecisionModel(), 4326);

    private final TipoInstitucionRepository tipoInstitucionRepository;
    private final InstitucionRepository institucionRepository;
    private final TipoVehiculoRepository tipoVehiculoRepository;
    private final CategoriaServicioRepository categoriaServicioRepository;
    private final EtiquetaCalificacionRepository etiquetaCalificacionRepository;
    private final ZonaRepository zonaRepository;
    private final TarifaRepository tarifaRepository;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        TipoInstitucion universidad = tipoInstitucion("UNIVERSIDAD", "Universidad");
        tipoInstitucion("INSTITUTO", "Instituto");
        tipoInstitucion("COLEGIO", "Colegio");
        if (institucionRepository.findBySiglaIgnoreCase("UAP").isEmpty()) {
            Institucion uap = new Institucion();
            uap.setTipoInstitucion(universidad);
            uap.setNombre("Universidad Amazonica de Pando");
            uap.setSigla("UAP");
            uap.setCiudad("Cobija");
            institucionRepository.save(uap);
            log.info("Catalogo base: institucion UAP creada");
        }

        TipoVehiculo sedan = tipoVehiculo("SEDAN", "Auto sedan", 4);
        TipoVehiculo moto = tipoVehiculo("MOTO", "Motocicleta", 1);
        tipoVehiculo("VAN", "Camioneta van", 7);

        Zona centro = zona("Centro", -68.775, -11.035, -68.745, -11.010);
        zona("Periferia", -68.800, -11.060, -68.745, -11.035);

        // Precios de referencia del seed (base, por km, por minuto).
        tarifa(categoria(sedan, "ESTANDAR"), centro, "6.00", "2.50", "0.30");
        tarifa(categoria(sedan, "EJECUTIVO"), centro, "9.00", "3.50", "0.40");
        tarifa(categoria(moto, "MOTO"), centro, "4.00", "1.80", "0.20");
        tarifa(categoria(moto, "DELIVERY"), centro, "4.00", "1.80", "0.20");

        if (etiquetaCalificacionRepository.count() == 0) {
            List.of(
                    etiqueta("Conduccion segura", TipoEtiqueta.POSITIVA, AplicaA.CONDUCTOR),
                    etiqueta("Puntual", TipoEtiqueta.POSITIVA, AplicaA.CONDUCTOR),
                    etiqueta("Vehiculo limpio", TipoEtiqueta.POSITIVA, AplicaA.CONDUCTOR),
                    etiqueta("Buen trato", TipoEtiqueta.POSITIVA, AplicaA.PASAJERO),
                    etiqueta("Pasajero puntual", TipoEtiqueta.POSITIVA, AplicaA.PASAJERO),
                    etiqueta("Respetuoso", TipoEtiqueta.POSITIVA, AplicaA.PASAJERO),
                    etiqueta("Conduccion brusca", TipoEtiqueta.NEGATIVA, AplicaA.CONDUCTOR),
                    etiqueta("Impuntual", TipoEtiqueta.NEGATIVA, AplicaA.CONDUCTOR),
                    etiqueta("Trato descortes", TipoEtiqueta.NEGATIVA, AplicaA.PASAJERO),
                    etiqueta("Cancelacion tardia", TipoEtiqueta.NEGATIVA, AplicaA.PASAJERO))
                    .forEach(etiquetaCalificacionRepository::save);
            log.info("Catalogo base: etiquetas de calificacion creadas");
        }
    }

    private TipoInstitucion tipoInstitucion(String codigo, String nombre) {
        return tipoInstitucionRepository.findByCodigo(codigo).orElseGet(() -> {
            TipoInstitucion tipo = new TipoInstitucion();
            tipo.setCodigo(codigo);
            tipo.setNombre(nombre);
            log.info("Catalogo base: tipo de institucion {} creado", codigo);
            return tipoInstitucionRepository.save(tipo);
        });
    }

    private TipoVehiculo tipoVehiculo(String codigo, String nombre, int capacidad) {
        return tipoVehiculoRepository.findByCodigo(codigo).orElseGet(() -> {
            TipoVehiculo tipo = new TipoVehiculo();
            tipo.setCodigo(codigo);
            tipo.setNombre(nombre);
            tipo.setCapacidadPasajeros(capacidad);
            log.info("Catalogo base: tipo de vehiculo {} creado", codigo);
            return tipoVehiculoRepository.save(tipo);
        });
    }

    /** La categoria [nombre] del tipo de vehiculo (activa); si no existe se crea. */
    private CategoriaServicio categoria(TipoVehiculo tipo, String nombre) {
        return categoriaServicioRepository.findByTipoVehiculoIdAndEstadoCategoriaServicio(tipo.getId(), EstadoRegistro.A)
                .stream()
                .filter(c -> nombre.equalsIgnoreCase(c.getNombre()))
                .findFirst()
                .orElseGet(() -> {
                    CategoriaServicio categoria = new CategoriaServicio();
                    categoria.setTipoVehiculo(tipo);
                    categoria.setNombre(nombre);
                    log.info("Catalogo base: categoria de servicio {} creada", nombre);
                    return categoriaServicioRepository.save(categoria);
                });
    }

    /** La zona [nombre] (activa); si no existe se crea con un rectangulo de Cobija. */
    private Zona zona(String nombre, double lonMin, double latMin, double lonMax, double latMax) {
        return zonaRepository.findAll().stream()
                .filter(z -> z.getEstadoZona() == EstadoRegistro.A && nombre.equalsIgnoreCase(z.getNombre()))
                .findFirst()
                .orElseGet(() -> {
                    Zona zona = new Zona();
                    zona.setNombre(nombre);
                    zona.setPoligono(rectangulo(lonMin, latMin, lonMax, latMax));
                    log.info("Catalogo base: zona {} creada", nombre);
                    return zonaRepository.save(zona);
                });
    }

    /** Una tarifa vigente para la categoria si no tiene ninguna activa. */
    private void tarifa(CategoriaServicio categoria, Zona zona, String base, String porKm, String porMinuto) {
        LocalDate hoy = LocalDate.now();
        boolean tieneVigente = tarifaRepository.findByCategoriaServicioId(categoria.getId()).stream()
                .anyMatch(t -> t.getEstadoTarifa() == EstadoRegistro.A
                        && (t.getVigenteDesde() == null || !t.getVigenteDesde().isAfter(hoy))
                        && (t.getVigenteHasta() == null || !t.getVigenteHasta().isBefore(hoy)));
        if (tieneVigente) return;
        Tarifa tarifa = new Tarifa();
        tarifa.setCategoriaServicio(categoria);
        tarifa.setZona(zona);
        tarifa.setTarifaBase(new BigDecimal(base));
        tarifa.setPrecioKm(new BigDecimal(porKm));
        tarifa.setPrecioMinuto(new BigDecimal(porMinuto));
        tarifa.setTarifaMinima(new BigDecimal(base));
        tarifa.setVigenteDesde(hoy.minusMonths(6));
        tarifaRepository.save(tarifa);
        log.info("Catalogo base: tarifa de referencia de {} creada", categoria.getNombre());
    }

    private static EtiquetaCalificacion etiqueta(String nombre, TipoEtiqueta tipo, AplicaA aplicaA) {
        EtiquetaCalificacion etiqueta = new EtiquetaCalificacion();
        etiqueta.setNombre(nombre);
        etiqueta.setTipo(tipo);
        etiqueta.setAplicaA(aplicaA);
        return etiqueta;
    }

    /** Rectangulo en WGS84; en JTS el orden es (longitud, latitud). */
    private static Polygon rectangulo(double lonMin, double latMin, double lonMax, double latMax) {
        return FABRICA.createPolygon(new Coordinate[] {
                new Coordinate(lonMin, latMin),
                new Coordinate(lonMax, latMin),
                new Coordinate(lonMax, latMax),
                new Coordinate(lonMin, latMax),
                new Coordinate(lonMin, latMin)
        });
    }
}
