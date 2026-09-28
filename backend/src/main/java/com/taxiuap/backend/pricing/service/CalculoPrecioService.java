package com.taxiuap.backend.pricing.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Optional;

import org.locationtech.jts.geom.Point;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.institution.entity.Estudiante;
import com.taxiuap.backend.institution.entity.MatriculaEstudiante;
import com.taxiuap.backend.institution.service.EstudianteService;
import com.taxiuap.backend.institution.service.MatriculaEstudianteService;
import com.taxiuap.backend.location.entity.Zona;
import com.taxiuap.backend.location.repository.ZonaRepository;
import com.taxiuap.backend.pricing.dto.CalculoPrecio;
import com.taxiuap.backend.pricing.entity.ReglaDescuentoEstudiantil;
import com.taxiuap.backend.pricing.entity.Tarifa;
import com.taxiuap.backend.pricing.repository.ReglaDescuentoEstudiantilRepository;
import com.taxiuap.backend.pricing.repository.TarifaRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.entity.OfertaViaje;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.repository.ViajeRepository;

import lombok.RequiredArgsConstructor;

/**
 * Calcula el precio de un viaje a partir de la solicitud del pasajero y la oferta aceptada del
 * conductor, aplicando el descuento estudiantil cuando corresponde (regla de negocio 3).
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CalculoPrecioService {

    /** Radio medio de la Tierra en kilometros, usado por la formula del haversine. */
    private static final double RADIO_TIERRA_KM = 6371.0;

    /** Velocidad urbana promedio usada para estimar la duracion del viaje. */
    private static final BigDecimal VELOCIDAD_URBANA_KMH = BigDecimal.valueOf(25);

    private final TarifaRepository tarifaRepository;
    private final ZonaRepository zonaRepository;
    private final ReglaDescuentoEstudiantilRepository reglaDescuentoRepository;
    private final EstudianteService estudianteService;
    private final MatriculaEstudianteService matriculaEstudianteService;
    private final ViajeRepository viajeRepository;

    /** Precio fijo del viaje (Bs), 8.00 si no se configura; vacio: el precio sale de la tarifa vigente. */
    @Value("${taxiuap.viaje.precio-fijo:8.00}")
    private BigDecimal precioFijo;

    @Value("${taxiuap.descuento-estudiantil.habilitado:false}")
    private boolean descuentoEstudiantilHabilitado;

    /** Precio fijo configurado, o null si el precio se calcula con la tarifa. */
    public BigDecimal precioFijo() {
        return precioFijo != null ? precioFijo.setScale(2, RoundingMode.HALF_UP) : null;
    }

    public CalculoPrecio calcular(SolicitudViaje solicitud, OfertaViaje oferta, Pasajero pasajero) {
        BigDecimal distanciaKm = calcularDistanciaKm(solicitud.getOrigen(), solicitud.getDestino());
        Integer duracionMin = calcularDuracionMin(distanciaKm);
        Tarifa tarifa = buscarTarifaVigente(solicitud);

        BigDecimal precioOriginal = calcularPrecioOriginal(oferta, tarifa, distanciaKm, duracionMin);
        ResultadoDescuento descuento = calcularDescuento(pasajero, solicitud, precioOriginal);

        BigDecimal precioFinal = precioOriginal.subtract(descuento.monto());
        if (precioFinal.compareTo(BigDecimal.ZERO) < 0) {
            precioFinal = BigDecimal.ZERO;
        }

        return new CalculoPrecio(
                precioOriginal.setScale(2, RoundingMode.HALF_UP),
                descuento.monto().setScale(2, RoundingMode.HALF_UP),
                precioFinal.setScale(2, RoundingMode.HALF_UP),
                tarifa,
                descuento.regla(),
                descuento.estudiante(),
                distanciaKm,
                duracionMin);
    }

    /**
     * Distancia en linea recta entre origen y destino (formula del haversine, radio 6371 km).
     * Es una aproximacion: no sigue calles ni trafico real. Cuando el proyecto incorpore un
     * servicio de rutas (por ejemplo OSRM o Google Directions), este es el unico lugar del
     * sistema que hay que reemplazar para que toda la app use distancia real en carretera.
     */
    private BigDecimal calcularDistanciaKm(Point origen, Point destino) {
        double lat1 = Math.toRadians(origen.getY());
        double lat2 = Math.toRadians(destino.getY());
        double deltaLat = Math.toRadians(destino.getY() - origen.getY());
        double deltaLon = Math.toRadians(destino.getX() - origen.getX());

        double a = Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2)
                + Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLon / 2) * Math.sin(deltaLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return BigDecimal.valueOf(RADIO_TIERRA_KM * c).setScale(2, RoundingMode.HALF_UP);
    }

    /** Duracion estimada a velocidad urbana constante, con un minimo de 1 minuto. */
    private Integer calcularDuracionMin(BigDecimal distanciaKm) {
        BigDecimal horas = distanciaKm.divide(VELOCIDAD_URBANA_KMH, 6, RoundingMode.HALF_UP);
        int minutos = horas.multiply(BigDecimal.valueOf(60)).setScale(0, RoundingMode.HALF_UP).intValue();
        return Math.max(1, minutos);
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

    /**
     * El modelo de TaxiUAP es de ofertas tipo inDrive: el conductor propone un precio y ese
     * precio manda sobre el calculado con la tarifa. La tarifa vigente solo sirve de referencia
     * cuando la oferta no trae un precio propio y como base para el descuento estudiantil.
     */
    private BigDecimal calcularPrecioOriginal(OfertaViaje oferta, Tarifa tarifa, BigDecimal distanciaKm,
            Integer duracionMin) {
        // Mientras haya precio fijo, todos los viajes cuestan lo mismo sin importar la oferta.
        if (precioFijo != null) {
            return precioFijo;
        }
        if (oferta.getPrecioOfertado() != null) {
            return oferta.getPrecioOfertado();
        }
        BigDecimal calculado = tarifa.getTarifaBase()
                .add(tarifa.getPrecioKm().multiply(distanciaKm))
                .add(tarifa.getPrecioMinuto().multiply(BigDecimal.valueOf(duracionMin)));
        return calculado.max(tarifa.getTarifaMinima());
    }

    /**
     * Regla de negocio 3: el descuento estudiantil solo aplica si el pasajero tiene un
     * Estudiante con matricula APROBADA y vigente, existe una regla vigente para su tipo de
     * institucion y el tipo de vehiculo de la categoria de servicio, y no supero el limite de
     * viajes con descuento del dia. Estudiante y regla solo se devuelven cuando el descuento
     * termino siendo mayor a cero, para que el viaje solo quede vinculado a ellos en ese caso.
     */
    private ResultadoDescuento calcularDescuento(Pasajero pasajero, SolicitudViaje solicitud,
            BigDecimal precioOriginal) {
        if (!descuentoEstudiantilHabilitado) {
            return ResultadoDescuento.sinDescuento();
        }
        Optional<Estudiante> estudianteOpt = estudianteService.buscarPorUsuario(pasajero.getUsuario().getId());
        if (estudianteOpt.isEmpty()) {
            return ResultadoDescuento.sinDescuento();
        }
        Estudiante estudiante = estudianteOpt.get();

        // La matricula debe estar APROBADA y no vencida (MatriculaEstudianteService.buscarVigenteAprobada).
        Optional<MatriculaEstudiante> matriculaOpt = matriculaEstudianteService.buscarVigenteAprobada(estudiante.getId());
        if (matriculaOpt.isEmpty()) {
            return ResultadoDescuento.sinDescuento();
        }

        Integer idTipoInstitucion = estudiante.getInstitucion().getTipoInstitucion().getId();
        Integer idTipoVehiculo = solicitud.getCategoriaServicio().getTipoVehiculo().getId();
        LocalDate hoy = LocalDate.now();

        // Debe existir una regla vigente para el tipo de institucion del estudiante y el tipo de
        // vehiculo de la categoria de servicio solicitada.
        Optional<ReglaDescuentoEstudiantil> reglaOpt = reglaDescuentoRepository.findAll().stream()
                .filter(regla -> regla.getEstadoReglaDescuento() == EstadoRegistro.A)
                .filter(regla -> regla.getTipoInstitucion().getId().equals(idTipoInstitucion))
                .filter(regla -> regla.getTipoVehiculo().getId().equals(idTipoVehiculo))
                .filter(regla -> cubreVigencia(regla.getVigenteDesde(), regla.getVigenteHasta(), hoy))
                .findFirst();
        if (reglaOpt.isEmpty()) {
            return ResultadoDescuento.sinDescuento();
        }
        ReglaDescuentoEstudiantil regla = reglaOpt.get();

        // Respeta viajes_maximos_dia: cuenta los viajes de hoy del estudiante con descuento aplicado.
        LocalDateTime inicioDia = hoy.atStartOfDay();
        LocalDateTime finDia = inicioDia.plusDays(1);
        long viajesConDescuentoHoy = viajeRepository.contarConDescuentoEnRango(estudiante.getId(), inicioDia, finDia);
        if (regla.getViajesMaximosDia() != null && viajesConDescuentoHoy >= regla.getViajesMaximosDia()) {
            return ResultadoDescuento.sinDescuento();
        }

        BigDecimal montoDescuento = precioOriginal.multiply(regla.getPorcentaje())
                .divide(BigDecimal.valueOf(100), 4, RoundingMode.HALF_UP);
        // El descuento nunca puede superar el monto_maximo de la regla.
        if (regla.getMontoMaximo() != null && montoDescuento.compareTo(regla.getMontoMaximo()) > 0) {
            montoDescuento = regla.getMontoMaximo();
        }

        if (montoDescuento.compareTo(BigDecimal.ZERO) <= 0) {
            return ResultadoDescuento.sinDescuento();
        }

        return new ResultadoDescuento(montoDescuento, regla, estudiante);
    }

    /** Resultado interno del calculo de descuento estudiantil. */
    private record ResultadoDescuento(BigDecimal monto, ReglaDescuentoEstudiantil regla, Estudiante estudiante) {

        static ResultadoDescuento sinDescuento() {
            return new ResultadoDescuento(BigDecimal.ZERO, null, null);
        }
    }
}
