package com.taxiuap.backend.pricing.service;

import java.math.BigDecimal;
import java.util.List;
import java.util.function.Function;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.pricing.dto.DescuentoEstudianteRequest;
import com.taxiuap.backend.pricing.dto.ParametrosPrecio;
import com.taxiuap.backend.pricing.dto.PrecioBaseRequest;
import com.taxiuap.backend.pricing.dto.TramoPrecioRequest;
import com.taxiuap.backend.pricing.entity.TramoPrecio;
import com.taxiuap.backend.pricing.repository.TramoPrecioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.sistema.entity.ConfiguracionSistema;
import com.taxiuap.backend.sistema.repository.ConfiguracionSistemaRepository;

import lombok.RequiredArgsConstructor;

/**
 * Precio del viaje en taxi que el administrador cambia en el panel; vale desde la siguiente cotizacion,
 * sin reiniciar el backend. El precio base (km y Bs) y el descuento de estudiante van en
 * configuracion_sistema (una fila por clave); los tramos adicionales en tramo_precio.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ParametrosPrecioService {

    static final String PRECIO_BASE = "viaje.precio-base";
    static final String KM_BASE = "viaje.km-base";
    static final String DESCUENTO_ESTUDIANTE = "estudiante.descuento";
    static final String VIAJES_ESTUDIANTE_DIA = "estudiante.viajes-por-dia";
    /** Claves del primer modelo (un solo tramo que se repetia): solo para crear los tramos iniciales. */
    static final String KM_TRAMO_ANTERIOR = "viaje.km-tramo";
    static final String PRECIO_TRAMO_ANTERIOR = "viaje.precio-tramo";

    private static final BigDecimal PRECIO_BASE_INICIAL = new BigDecimal("8.00");
    private static final BigDecimal KM_BASE_INICIAL = new BigDecimal("5");

    private final ConfiguracionSistemaRepository configuracionRepository;
    private final TramoPrecioRepository tramoRepository;

    public ParametrosPrecio actuales() {
        List<ParametrosPrecio.Tramo> tramos = tramoRepository.findByEstadoTramoOrderByOrdenAscIdAsc(EstadoRegistro.A)
                .stream()
                .map(t -> new ParametrosPrecio.Tramo(t.getId(), t.getKmAdicional(), t.getCostoAdicional(), t.getOrden()))
                .toList();
        return new ParametrosPrecio(
                leer(PRECIO_BASE, BigDecimal::new, PRECIO_BASE_INICIAL),
                leer(KM_BASE, BigDecimal::new, KM_BASE_INICIAL),
                tramos,
                leer(DESCUENTO_ESTUDIANTE, Integer::valueOf, 0),
                leer(VIAJES_ESTUDIANTE_DIA, Integer::valueOf, null));
    }

    @Transactional
    public ParametrosPrecio guardarBase(PrecioBaseRequest datos) {
        if (BigDecimal.valueOf(actuales().descuentoEstudiante()).compareTo(datos.precioBase()) >= 0) {
            throw new NegocioException("El precio base debe ser mayor que el descuento de estudiante");
        }
        escribir(PRECIO_BASE, datos.precioBase().toPlainString());
        escribir(KM_BASE, datos.kmBase().toPlainString());
        return actuales();
    }

    /** Agrega un tramo al final. */
    @Transactional
    public ParametrosPrecio crearTramo(TramoPrecioRequest datos) {
        int orden = tramoRepository.findByEstadoTramoOrderByOrdenAscIdAsc(EstadoRegistro.A).stream()
                .mapToInt(TramoPrecio::getOrden).max().orElse(0) + 1;
        TramoPrecio tramo = new TramoPrecio();
        tramo.setOrden(orden);
        aplicar(tramo, datos);
        tramoRepository.save(tramo);
        return actuales();
    }

    @Transactional
    public ParametrosPrecio editarTramo(Integer id, TramoPrecioRequest datos) {
        aplicar(activo(id), datos);
        return actuales();
    }

    /** Borrado logico: el tramo deja de contar y los siguientes se recalculan solos. */
    @Transactional
    public ParametrosPrecio eliminarTramo(Integer id) {
        activo(id).setEstadoTramo(EstadoRegistro.X);
        return actuales();
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
     * Si todavia no hay ningun tramo (ni eliminado) se crean dos iguales al tramo del primer modelo
     * (por defecto +3 km +2 Bs): asi el precio de hoy no cambia. Lo llama TramosPrecioInitializer.
     */
    @Transactional
    public void crearTramosIniciales() {
        if (tramoRepository.count() > 0) return;
        BigDecimal km = leer(KM_TRAMO_ANTERIOR, BigDecimal::new, new BigDecimal("3"));
        BigDecimal costo = leer(PRECIO_TRAMO_ANTERIOR, BigDecimal::new, new BigDecimal("2.00"));
        for (int orden = 1; orden <= 2; orden++) {
            TramoPrecio tramo = new TramoPrecio();
            tramo.setOrden(orden);
            aplicar(tramo, new TramoPrecioRequest(km, costo));
            tramoRepository.save(tramo);
        }
    }

    private TramoPrecio activo(Integer id) {
        return tramoRepository.findById(id)
                .filter(t -> t.getEstadoTramo() == EstadoRegistro.A)
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
