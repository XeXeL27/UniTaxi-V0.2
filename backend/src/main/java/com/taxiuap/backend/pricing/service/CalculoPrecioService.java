package com.taxiuap.backend.pricing.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Optional;

import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.institution.entity.Estudiante;
import com.taxiuap.backend.institution.service.EstudianteService;
import com.taxiuap.backend.institution.service.MatriculaEstudianteService;
import com.taxiuap.backend.location.entity.Zona;
import com.taxiuap.backend.location.repository.ZonaRepository;
import com.taxiuap.backend.pricing.dto.CalculoPrecio;
import com.taxiuap.backend.pricing.dto.CotizacionViaje;
import com.taxiuap.backend.pricing.dto.ParametrosPrecio;
import com.taxiuap.backend.pricing.entity.Tarifa;
import com.taxiuap.backend.pricing.repository.TarifaRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.entity.OfertaViaje;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.repository.ViajeRepository;

import lombok.RequiredArgsConstructor;

/**
 * Precio del viaje en taxi. El servidor mide la distancia por calles (DistanciaRutaService) y le
 * aplica el precio por tramos que el administrador edita en el panel (ParametrosPrecio): precio base
 * hasta ciertos km y un monto por cada tramo adicional. Al estudiante con matricula vigente se le
 * resta un descuento fijo en Bs (regla de negocio 3); lo pone el conductor, que cobra menos.
 *
 * El precio y el descuento quedan fijos en la solicitud al pedirla, y el viaje los copia al
 * aceptarse: lo que el pasajero vio es lo que paga.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CalculoPrecioService {

    private final TarifaRepository tarifaRepository;
    private final ZonaRepository zonaRepository;
    private final EstudianteService estudianteService;
    private final MatriculaEstudianteService matriculaEstudianteService;
    private final ViajeRepository viajeRepository;
    private final ParametrosPrecioService parametrosPrecioService;
    private final DistanciaRutaService distanciaRutaService;

    /** Precio base vigente (el de los primeros km), para mostrar antes de elegir destino. */
    public BigDecimal precioBase() {
        return parametrosPrecioService.actuales().precioBase();
    }

    /** Precio de un viaje de [origen] a [destino] para [pasajero], con su descuento de estudiante. */
    public CotizacionViaje cotizar(Pasajero pasajero, Point origen, Point destino) {
        ParametrosPrecio parametros = parametrosPrecioService.actuales();
        DistanciaRutaService.DistanciaRuta distancia = distanciaRutaService.medir(origen, destino);
        BigDecimal precioNormal = parametros.precioPara(distancia.km());
        Optional<Estudiante> estudiante = estudianteConDescuento(pasajero, parametros);
        BigDecimal descuento = estudiante.isPresent()
                ? BigDecimal.valueOf(parametros.descuentoEstudiante()).min(precioNormal).setScale(2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO.setScale(2);
        return new CotizacionViaje(distancia.km(), distancia.minutos(), distancia.porCalles(), precioNormal,
                descuento, precioNormal.subtract(descuento), descuento.signum() > 0 ? estudiante.get() : null);
    }

    /** Precio del viaje que nace de [solicitud]: el que quedo fijado al pedirla. */
    public CalculoPrecio calcular(SolicitudViaje solicitud, OfertaViaje oferta, Pasajero pasajero) {
        BigDecimal distanciaKm = solicitud.getDistanciaKm() != null ? solicitud.getDistanciaKm()
                : DistanciaRutaService.lineaRecta(solicitud.getOrigen(), solicitud.getDestino()).km();
        Integer duracionMin = DistanciaRutaService.lineaRecta(solicitud.getOrigen(), solicitud.getDestino()).minutos();
        Tarifa tarifa = buscarTarifaVigente(solicitud);

        // Solicitudes de antes del precio por tramos: se calcula con los parametros actuales.
        BigDecimal precioOriginal = solicitud.getPrecioSugerido() != null ? solicitud.getPrecioSugerido()
                : parametrosPrecioService.actuales().precioPara(distanciaKm);
        BigDecimal descuento = solicitud.getDescuentoEstudiante() != null ? solicitud.getDescuentoEstudiante()
                : BigDecimal.ZERO;
        descuento = descuento.min(precioOriginal).max(BigDecimal.ZERO);
        Estudiante estudiante = descuento.signum() > 0
                ? estudianteService.buscarPorUsuario(pasajero.getUsuario().getId()).orElse(null)
                : null;
        if (estudiante == null) descuento = BigDecimal.ZERO;

        return new CalculoPrecio(
                precioOriginal.setScale(2, RoundingMode.HALF_UP),
                descuento.setScale(2, RoundingMode.HALF_UP),
                precioOriginal.subtract(descuento).setScale(2, RoundingMode.HALF_UP),
                tarifa,
                null,
                estudiante,
                distanciaKm,
                duracionMin);
    }

    /**
     * Regla de negocio 3: descuento solo con matricula APROBADA y vigente, un descuento configurado
     * mayor a cero y sin pasar el maximo de viajes con descuento del dia.
     */
    private Optional<Estudiante> estudianteConDescuento(Pasajero pasajero, ParametrosPrecio parametros) {
        if (parametros.descuentoEstudiante() == null || parametros.descuentoEstudiante() <= 0) {
            return Optional.empty();
        }
        Optional<Estudiante> estudiante = estudianteService.buscarPorUsuario(pasajero.getUsuario().getId())
                .filter(e -> matriculaEstudianteService.buscarVigenteAprobada(e.getId()).isPresent());
        if (estudiante.isEmpty() || parametros.viajesEstudiantePorDia() == null) {
            return estudiante;
        }
        LocalDateTime inicioDia = LocalDate.now().atStartOfDay();
        long hoy = viajeRepository.contarConDescuentoEnRango(estudiante.get().getId(), inicioDia, inicioDia.plusDays(1));
        return hoy < parametros.viajesEstudiantePorDia() ? estudiante : Optional.empty();
    }

    /**
     * Tarifa vigente para la categoria de servicio de la solicitud. Se intenta primero con la
     * zona activa cuyo poligono contiene el origen del viaje; si ninguna zona lo contiene (o no
     * tiene tarifa vigente), se usa la primera tarifa vigente de la categoria sin importar zona.
     */
    private Tarifa buscarTarifaVigente(SolicitudViaje solicitud) {
        Integer idCategoriaServicio = solicitud.getCategoriaServicio().getId();
        LocalDate hoy = LocalDate.now();

        Optional<Tarifa> tarifaDeZona = zonaRepository.findAll().stream()
                .filter(zona -> zona.getEstadoZona() == EstadoRegistro.A)
                .filter(zona -> contieneOrigen(zona, solicitud.getOrigen()))
                .flatMap(zona -> tarifaRepository
                        .findByCategoriaServicioIdAndZonaId(idCategoriaServicio, zona.getId()).stream())
                .filter(tarifa -> tarifa.getEstadoTarifa() == EstadoRegistro.A)
                .filter(tarifa -> cubreVigencia(tarifa.getVigenteDesde(), tarifa.getVigenteHasta(), hoy))
                .findFirst();

        return tarifaDeZona
                .or(() -> tarifaRepository.findByCategoriaServicioId(idCategoriaServicio).stream()
                        .filter(tarifa -> tarifa.getEstadoTarifa() == EstadoRegistro.A)
                        .filter(tarifa -> cubreVigencia(tarifa.getVigenteDesde(), tarifa.getVigenteHasta(), hoy))
                        .findFirst())
                .orElseThrow(() -> new NegocioException("No hay una tarifa vigente para la categoria de servicio"));
    }

    private boolean contieneOrigen(Zona zona, Point origen) {
        return zona.getPoligono() != null && zona.getPoligono().contains(origen);
    }

    private boolean cubreVigencia(LocalDate desde, LocalDate hasta, LocalDate hoy) {
        boolean empezoOnTime = desde != null && !desde.isAfter(hoy);
        boolean noVencio = hasta == null || !hasta.isBefore(hoy);
        return empezoOnTime && noVencio;
    }
}
