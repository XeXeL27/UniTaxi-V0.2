package com.taxiuap.backend.location.service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.location.dto.LatidoPasajeroRequest;
import com.taxiuap.backend.location.dto.PasajeroEnLineaResponse;
import com.taxiuap.backend.location.enums.ActividadPasajero;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.trip.repository.ViajeRepository;

/**
 * Pasajeros con la app abierta y su ultima posicion, para el mapa Usuarios en linea del panel.
 *
 * Vive SOLO en memoria (sin tabla ni historial): la app manda su posicion mientras esta en
 * pantalla y, sin latido por taxiuap.pasajeros.segundos-en-linea, el pasajero sale del mapa. Al
 * reiniciar el servidor la lista empieza vacia y se llena con los siguientes latidos.
 */
@Service
public class PresenciaPasajeroService {

    private static final List<SituacionSolicitud> SOLICITUD_ACTIVA =
            List.of(SituacionSolicitud.PENDIENTE, SituacionSolicitud.CON_OFERTAS);
    private static final List<SituacionViaje> VIAJE_TERMINADO =
            List.of(SituacionViaje.COMPLETADO, SituacionViaje.CANCELADO);

    private final PasajeroRepository pasajeroRepository;
    private final SolicitudViajeRepository solicitudViajeRepository;
    private final ViajeRepository viajeRepository;
    private final PasajeroUbicacionPublisher publisher;
    private final Clock reloj;

    /** Por id de pasajero. */
    private final Map<Long, PasajeroEnLineaResponse> enLinea = new ConcurrentHashMap<>();

    @Value("${taxiuap.pasajeros.segundos-en-linea:90}")
    private long segundosEnLinea = 90;

    @Autowired
    public PresenciaPasajeroService(PasajeroRepository pasajeroRepository,
            SolicitudViajeRepository solicitudViajeRepository, ViajeRepository viajeRepository,
            PasajeroUbicacionPublisher publisher) {
        this(pasajeroRepository, solicitudViajeRepository, viajeRepository, publisher, Clock.systemDefaultZone());
    }

    PresenciaPasajeroService(PasajeroRepository pasajeroRepository,
            SolicitudViajeRepository solicitudViajeRepository, ViajeRepository viajeRepository,
            PasajeroUbicacionPublisher publisher, Clock reloj) {
        this.pasajeroRepository = pasajeroRepository;
        this.solicitudViajeRepository = solicitudViajeRepository;
        this.viajeRepository = viajeRepository;
        this.publisher = publisher;
        this.reloj = reloj;
    }

    /** Guarda la posicion del pasajero (por su cuenta de usuario) y la manda al panel. */
    @Transactional(readOnly = true)
    public PasajeroEnLineaResponse registrar(Long idUsuario, LatidoPasajeroRequest request) {
        Pasajero pasajero = pasajeroRepository.findByUsuarioId(idUsuario)
                .filter(p -> EstadoRegistro.A.equals(p.getEstadoPasajero()))
                .orElseThrow(() -> new NegocioException("Esta cuenta no es de pasajero"));
        var persona = pasajero.getUsuario().getPersona();
        PasajeroEnLineaResponse posicion = new PasajeroEnLineaResponse(
                pasajero.getId(),
                idUsuario,
                persona.getNombres(),
                persona.getApellidos(),
                request.latitud(),
                request.longitud(),
                actividadDe(pasajero.getId()),
                reloj.instant(),
                true);
        enLinea.put(pasajero.getId(), posicion);
        publisher.publicar(posicion);
        return posicion;
    }

    /** La app se minimizo, se cerro o cerro sesion: el pasajero sale del mapa enseguida. */
    public void salir(Long idUsuario) {
        enLinea.values().stream()
                .filter(p -> idUsuario.equals(p.idUsuario()))
                .findFirst()
                .ifPresent(this::quitar);
    }

    /** Pasajeros en linea ahora, del ultimo latido al mas viejo. */
    public List<PasajeroEnLineaResponse> enLinea() {
        Instant limite = limite();
        return enLinea.values().stream()
                .filter(p -> p.actualizadoEn().isAfter(limite))
                .sorted(Comparator.comparing(PasajeroEnLineaResponse::actualizadoEn).reversed())
                .toList();
    }

    /** Quita a los que dejaron de mandar su posicion (la app se cerro sin avisar o sin senal). */
    @Scheduled(initialDelayString = "PT30S", fixedDelayString = "PT20S")
    public void quitarSinLatido() {
        Instant limite = limite();
        List.copyOf(enLinea.values()).stream()
                .filter(p -> !p.actualizadoEn().isAfter(limite))
                .forEach(this::quitar);
    }

    private void quitar(PasajeroEnLineaResponse posicion) {
        if (enLinea.remove(posicion.idPasajero(), posicion)) {
            publisher.publicar(posicion.fuera());
        }
    }

    private Instant limite() {
        return reloj.instant().minus(Duration.ofSeconds(segundosEnLinea));
    }

    private ActividadPasajero actividadDe(Long idPasajero) {
        if (viajeRepository.countByPasajeroIdAndSituacionViajeNotIn(idPasajero, VIAJE_TERMINADO) > 0) {
            return ActividadPasajero.EN_VIAJE;
        }
        if (solicitudViajeRepository.existsByPasajeroIdAndSituacionSolicitudInAndEstadoSolViaje(
                idPasajero, SOLICITUD_ACTIVA, EstadoRegistro.A)) {
            return ActividadPasajero.BUSCANDO;
        }
        return ActividadPasajero.LIBRE;
    }
}
