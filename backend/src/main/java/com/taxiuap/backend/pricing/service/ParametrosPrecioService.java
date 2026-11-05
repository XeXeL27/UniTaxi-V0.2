package com.taxiuap.backend.pricing.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.function.Function;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.pricing.dto.DescuentoEstudianteRequest;
import com.taxiuap.backend.pricing.dto.ParametrosPrecio;
import com.taxiuap.backend.pricing.dto.PrecioBaseRequest;
import com.taxiuap.backend.pricing.dto.TarifaDelivery;
import com.taxiuap.backend.pricing.dto.TramoPrecioRequest;
import com.taxiuap.backend.pricing.entity.TramoPrecio;
import com.taxiuap.backend.pricing.enums.ServicioPrecio;
import com.taxiuap.backend.pricing.repository.TramoPrecioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.sistema.entity.ConfiguracionSistema;
import com.taxiuap.backend.sistema.repository.ConfiguracionSistemaRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Tablas de precios por km que el administrador cambia en el panel: la del moto taxi (Precio del viaje),
 * la del paquete y la del delivery (ver ServicioPrecio); valen desde la siguiente cotizacion o pedido,
 * sin reiniciar el backend. El precio base (km y Bs) de cada una y el descuento de estudiante (solo del
 * taxi) van en configuracion_sistema; los tramos adicionales en tramo_precio con su servicio.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ParametrosPrecioService {

    static final String PRECIO_BASE = ServicioPrecio.TAXI.clavePrecioBase();
    static final String KM_BASE = ServicioPrecio.TAXI.claveKmBase();
    static final String DESCUENTO_ESTUDIANTE = "estudiante.descuento";
    static final String VIAJES_ESTUDIANTE_DIA = "estudiante.viajes-por-dia";
    /** Claves del primer modelo (un solo tramo que se repetia): solo para crear los tramos iniciales. */
    static final String KM_TRAMO_ANTERIOR = "viaje.km-tramo";
    static final String PRECIO_TRAMO_ANTERIOR = "viaje.precio-tramo";

    private static final BigDecimal PRECIO_BASE_INICIAL = new BigDecimal("8.00");
    private static final BigDecimal KM_BASE_INICIAL = new BigDecimal("5");
    /** El paquete y el delivery empiezan cubriendo 1 km con su precio base (ver crearTablasDeEnvioIniciales). */
    private static final BigDecimal KM_BASE_ENVIO_INICIAL = BigDecimal.ONE;

    private final ConfiguracionSistemaRepository configuracionRepository;
    private final TramoPrecioRepository tramoRepository;
    private final TarifaDeliveryService tarifaDeliveryService;

    /** Tabla del moto taxi. */
    public ParametrosPrecio actuales() {
        return actuales(ServicioPrecio.TAXI);
    }

    public ParametrosPrecio actuales(ServicioPrecio servicio) {
        List<ParametrosPrecio.Tramo> tramos = tramoRepository
                .findByServicioAndEstadoTramoOrderByOrdenAscIdAsc(servicio, EstadoRegistro.A)
                .stream()
                .map(t -> new ParametrosPrecio.Tramo(t.getId(), t.getKmAdicional(), t.getCostoAdicional(), t.getOrden()))
                .toList();
        boolean taxi = servicio == ServicioPrecio.TAXI;
        return new ParametrosPrecio(
                leer(servicio.clavePrecioBase(), BigDecimal::new, taxi ? PRECIO_BASE_INICIAL : precioBaseEnvioInicial(servicio)),
                leer(servicio.claveKmBase(), BigDecimal::new, taxi ? KM_BASE_INICIAL : KM_BASE_ENVIO_INICIAL),
                tramos,
                taxi ? leer(DESCUENTO_ESTUDIANTE, Integer::valueOf, 0) : 0,
                taxi ? leer(VIAJES_ESTUDIANTE_DIA, Integer::valueOf, null) : null);
    }

    @Transactional
    public ParametrosPrecio guardarBase(PrecioBaseRequest datos) {
        return guardarBase(ServicioPrecio.TAXI, datos);
    }

    @Transactional
    public ParametrosPrecio guardarBase(ServicioPrecio servicio, PrecioBaseRequest datos) {
        if (servicio == ServicioPrecio.TAXI
                && BigDecimal.valueOf(actuales().descuentoEstudiante()).compareTo(datos.precioBase()) >= 0) {
            throw new NegocioException("El precio base debe ser mayor que el descuento de estudiante");
        }
        escribir(servicio.clavePrecioBase(), datos.precioBase().toPlainString());
        escribir(servicio.claveKmBase(), datos.kmBase().toPlainString());
        log.info("Precio base de {} guardado: hasta {} km = {} Bs", servicio.nombre(), datos.kmBase(), datos.precioBase());
        return actuales(servicio);
    }

    /** Agrega un tramo al final de la tabla del moto taxi. */
    @Transactional
    public ParametrosPrecio crearTramo(TramoPrecioRequest datos) {
        return crearTramo(ServicioPrecio.TAXI, datos);
    }

    @Transactional
    public ParametrosPrecio crearTramo(ServicioPrecio servicio, TramoPrecioRequest datos) {
        int orden = tramoRepository.findByServicioAndEstadoTramoOrderByOrdenAscIdAsc(servicio, EstadoRegistro.A).stream()
                .mapToInt(TramoPrecio::getOrden).max().orElse(0) + 1;
        TramoPrecio tramo = new TramoPrecio();
        tramo.setServicio(servicio);
        tramo.setOrden(orden);
        aplicar(tramo, datos);
        tramoRepository.save(tramo);
        return actuales(servicio);
    }

    @Transactional
    public ParametrosPrecio editarTramo(Integer id, TramoPrecioRequest datos) {
        return editarTramo(ServicioPrecio.TAXI, id, datos);
    }

    @Transactional
    public ParametrosPrecio editarTramo(ServicioPrecio servicio, Integer id, TramoPrecioRequest datos) {
        aplicar(activo(servicio, id), datos);
        return actuales(servicio);
    }

    /** Borrado logico: el tramo deja de contar y los siguientes se recalculan solos. */
    @Transactional
    public ParametrosPrecio eliminarTramo(Integer id) {
        return eliminarTramo(ServicioPrecio.TAXI, id);
    }

    @Transactional
    public ParametrosPrecio eliminarTramo(ServicioPrecio servicio, Integer id) {
        activo(servicio, id).setEstadoTramo(EstadoRegistro.X);
        return actuales(servicio);
    }

    @Transactional
    public ParametrosPrecio guardarDescuento(DescuentoEstudianteRequest datos) {
        if (BigDecimal.valueOf(datos.descuentoEstudiante()).compareTo(actuales().precioBase()) >= 0) {
            throw new NegocioException("El descuento de estudiante debe ser menor que el precio base");
        }
        escribir(DESCUENTO_ESTUDIANTE, datos.descuentoEstudiante().toString());
        escribir(VIAJES_ESTUDIANTE_DIA,
                datos.viajesEstudiantePorDia() == null ? null : datos.viajesEstudiantePorDia().toString());
        return actuales();
    }

    /**
     * Si todavia no hay ningun tramo del moto taxi (ni eliminado) se crean dos iguales al tramo del primer
     * modelo (por defecto +3 km +2 Bs): asi el precio de hoy no cambia. Lo llama TramosPrecioInitializer.
     * Antes, los tramos de antes de separar los servicios quedan como del moto taxi.
     */
    @Transactional
    public void crearTramosIniciales() {
        tramoRepository.asignarTaxiALosDeAntes();
        if (tramoRepository.countByServicio(ServicioPrecio.TAXI) > 0) return;
        BigDecimal km = leer(KM_TRAMO_ANTERIOR, BigDecimal::new, new BigDecimal("3"));
        BigDecimal costo = leer(PRECIO_TRAMO_ANTERIOR, BigDecimal::new, new BigDecimal("2.00"));
        for (int orden = 1; orden <= 2; orden++) {
            TramoPrecio tramo = new TramoPrecio();
            tramo.setServicio(ServicioPrecio.TAXI);
            tramo.setOrden(orden);
            aplicar(tramo, new TramoPrecioRequest(km, costo));
            tramoRepository.save(tramo);
        }
    }

    /**
     * La primera vez, el paquete y el delivery reciben una tabla parecida a su tarifa de antes (base +
     * precio por km), pero en Bs enteros: el precio base de antes cubre el primer km y cada km mas suma el
     * precio por km de antes redondeado hacia arriba (8 Bs + 2 Bs por km -> hasta 1 km 8 Bs, +1 km +2 Bs).
     * Si ya tienen precio base guardado o algun tramo (aunque este eliminado) no se toca.
     */
    @Transactional
    public void crearTablasDeEnvioIniciales() {
        for (ServicioPrecio servicio : List.of(ServicioPrecio.PAQUETE, ServicioPrecio.DELIVERY)) {
            if (tramoRepository.countByServicio(servicio) > 0 || guardada(servicio.clavePrecioBase())) continue;
            TarifaDelivery anterior = tarifaAnterior(servicio);
            BigDecimal base = enteroHaciaArriba(anterior.tarifaBase());
            BigDecimal porKm = enteroHaciaArriba(anterior.precioKm());
            escribir(servicio.clavePrecioBase(), base.toPlainString());
            escribir(servicio.claveKmBase(), KM_BASE_ENVIO_INICIAL.toPlainString());
            if (porKm.signum() > 0) {
                TramoPrecio tramo = new TramoPrecio();
                tramo.setServicio(servicio);
                tramo.setOrden(1);
                aplicar(tramo, new TramoPrecioRequest(BigDecimal.ONE, porKm));
                tramoRepository.save(tramo);
            }
            log.info("Tabla de precios inicial de {}: hasta 1 km {} Bs, cada km mas +{} Bs (antes {} Bs + {} Bs por km)",
                    servicio.nombre(), base, porKm, anterior.tarifaBase(), anterior.precioKm());
        }
    }

    private TarifaDelivery tarifaAnterior(ServicioPrecio servicio) {
        return servicio == ServicioPrecio.PAQUETE ? tarifaDeliveryService.paquete() : tarifaDeliveryService.actual();
    }

    private BigDecimal precioBaseEnvioInicial(ServicioPrecio servicio) {
        return enteroHaciaArriba(tarifaAnterior(servicio).tarifaBase());
    }

    private static BigDecimal enteroHaciaArriba(BigDecimal valor) {
        return valor.setScale(0, RoundingMode.CEILING).setScale(2);
    }

    private boolean guardada(String clave) {
        return configuracionRepository.findByClave(clave)
                .map(ConfiguracionSistema::getValor)
                .filter(valor -> valor != null && !valor.isBlank())
                .isPresent();
    }

    private TramoPrecio activo(ServicioPrecio servicio, Integer id) {
        return tramoRepository.findById(id)
                .filter(t -> t.getEstadoTramo() == EstadoRegistro.A)
                .filter(t -> (t.getServicio() == null ? ServicioPrecio.TAXI : t.getServicio()) == servicio)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Tramo", id));
    }

    private static void aplicar(TramoPrecio tramo, TramoPrecioRequest datos) {
        tramo.setKmAdicional(datos.kmAdicional());
        tramo.setCostoAdicional(datos.costoAdicional());
        tramo.setEstadoTramo(EstadoRegistro.A);
    }

    private <T> T leer(String clave, Function<String, T> convertir, T porDefecto) {
        return configuracionRepository.findByClave(clave)
                .map(ConfiguracionSistema::getValor)
                .filter(valor -> !valor.isBlank())
                .map(valor -> {
                    try {
                        return convertir.apply(valor.trim());
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
}
