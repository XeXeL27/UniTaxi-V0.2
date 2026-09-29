package com.taxiuap.backend.location.service;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.location.dto.ConductorEnLineaResponse;
import com.taxiuap.backend.location.dto.PosicionConductor;
import com.taxiuap.backend.location.dto.PosicionConductorMensaje;
import com.taxiuap.backend.location.dto.UbicacionConductorRequest;
import com.taxiuap.backend.location.entity.DisponibilidadConductor;
import com.taxiuap.backend.location.entity.UbicacionConductor;
import com.taxiuap.backend.location.enums.Disponibilidad;
import com.taxiuap.backend.location.repository.DisponibilidadConductorRepository;
import com.taxiuap.backend.location.repository.UbicacionConductorRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.service.SeguimientoViajePublisher;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

import lombok.RequiredArgsConstructor;

/**
 * Servicio de la ubicacion de los conductores.
 *
 * Concentra tres cosas: guardar el reporte de posicion que llega por WebSocket, mantener el
 * historial de disponibilidad y armar la lista de flota que consume el panel.
 */
@Service
@RequiredArgsConstructor
public class UbicacionService {

    /** SRID 4326: las coordenadas del reporte ya vienen en grados, como las guarda PostGIS. */
    private static final int SRID = 4326;
    private static final GeometryFactory FABRICA_GEOMETRIA =
            new GeometryFactory(new PrecisionModel(), SRID);

    private final UbicacionConductorRepository ubicacionConductorRepository;
    private final DisponibilidadConductorRepository disponibilidadConductorRepository;
    private final ConductorRepository conductorRepository;
    private final VehiculoRepository vehiculoRepository;
    private final ConductorUbicacionPublisher publisher;
    private final SeguimientoViajePublisher seguimientoViajePublisher;

    @Value("${taxiuap.conductores.segundos-en-linea:120}")
    private long segundosEnLinea;

    /**
     * Registra la posicion de quien se identifica por su cuenta de usuario, que es como llega el
     * reporte por WebSocket: el frame CONNECT trae el id de usuario, no el de conductor.
     *
     * Los dos identificadores no son el mismo numero aunque en la base de datos suelen coincidir en
     * los datos de prueba, y buscar por el equivocado permitiria que cualquier usuario autenticado
     * moviera el marcador de un conductor ajeno. Por eso se resuelve la cuenta de conductor por
     * id de usuario y se exige el rol.
     *
     * @throws NegocioException si el rol no es CONDUCTOR o la cuenta no es de conductor
     */
    @Transactional
    public PosicionConductorMensaje registrarPorUsuario(Long idUsuario, String rol,
            UbicacionConductorRequest request) {
        if (!RolSistema.CONDUCTOR.getCodigo().equals(rol)) {
            throw new NegocioException("Solo un conductor puede reportar su posicion");
        }
        Conductor conductor = conductorRepository.findByUsuarioId(idUsuario)
                .orElseThrow(() -> new NegocioException(
                        "El usuario " + idUsuario + " no tiene una cuenta de conductor"));
        return registrar(conductor.getId(), request);
    }

    /**
     * Registra la posicion que reporto un conductor y la difunde a los administradores.
     *
     * @throws NegocioException si el conductor no existe o no esta aprobado para operar
     */
    @Transactional
    public PosicionConductorMensaje registrar(Long idConductor, UbicacionConductorRequest request) {
        Conductor conductor = buscarConductorOperativo(idConductor);

        UbicacionConductor ubicacion = ubicacionConductorRepository.findByConductorId(idConductor)
                .orElseGet(() -> nuevaUbicacion(conductor));
        ubicacion.setConductor(conductor);
        ubicacion.setUbicacion(crearPunto(request.latitud(), request.longitud()));
        ubicacion.setRumbo(request.rumbo());
        ubicacion.setVelocidad(request.velocidad());
        LocalDateTime ahora = LocalDateTime.now();
        ubicacion.setActualizadoEn(ahora);
        ubicacion.setEstadoUbicacionConductor(EstadoRegistro.A);
        ubicacionConductorRepository.save(ubicacion);

        // El valor con el que se responde es el recien guardado, no el de la consulta anterior, para
        // que el conductor vea en su propia respuesta el estado que acabamos de registrar.
        Disponibilidad disponibilidad = registrarDisponibilidad(conductor, request.disponibilidad(), ahora);

        PosicionConductorMensaje mensaje = new PosicionConductorMensaje(
                idConductor,
                request.latitud(),
                request.longitud(),
                request.rumbo() == null ? null : request.rumbo().doubleValue(),
                request.velocidad() == null ? null : request.velocidad().doubleValue(),
                disponibilidad,
                aInstante(ahora));
        publisher.publicarPosicion(mensaje);
        seguimientoViajePublisher.publicarAlPasajero(mensaje);
        return mensaje;
    }

    /**
     * Lista de flota para el mapa del panel: todos los conductores aprobados, tengan o no posicion.
     *
     * Un conductor sin reporte todavia entra, marcado como desconectado, para que el panel no tenga
     * que adivinar cuantos faltan. El mapa distingue "nunca reporto" de "reporto hace rato" porque
     * el segundo caso trae actualizadoEn y el primero lo trae nulo.
     */
    @Transactional(readOnly = true)
    public List<PosicionConductor> listaFlota() {
        List<Conductor> conductores = conductorRepository
                .findBySituacionAprobacionAndEstadoConductorOrderByIdAsc(
                        SituacionAprobacion.APROBADO, EstadoRegistro.A);
        if (conductores.isEmpty()) {
            return List.of();
        }

        List<Long> idConductores = conductores.stream().map(Conductor::getId).toList();

        Map<Long, UbicacionConductor> porConductor = new HashMap<>();
        for (UbicacionConductor ubicacion : ubicacionConductorRepository.findByConductorIdIn(idConductores)) {
            porConductor.put(ubicacion.getConductor().getId(), ubicacion);
        }

        Map<Long, String> placas = new HashMap<>();
        for (Vehiculo vehiculo : vehiculoRepository
                .findByConductorIdInAndEstadoVehiculoOrderByIdAsc(idConductores, EstadoRegistro.A)) {
            placas.putIfAbsent(vehiculo.getConductor().getId(), vehiculo.getPlaca());
        }

        Map<Long, Disponibilidad> disponibilidades = new HashMap<>();
        for (DisponibilidadConductor registro : disponibilidadConductorRepository
                .findByConductorIdInAndEstadoDisponibilidadConductorOrderByConductorIdAscDesdeDesc(
                        idConductores, EstadoRegistro.A)) {
            // La consulta viene de mas nuevo a mas viejo por conductor, asi que el primero que
            // aparece de cada uno es el vigente y los siguientes se descartan.
            disponibilidades.putIfAbsent(registro.getConductor().getId(), registro.getDisponibilidad());
        }

        return conductores.stream().map(conductor -> {
            UbicacionConductor ubicacion = porConductor.get(conductor.getId());
            var persona = conductor.getUsuario().getPersona();
            return new PosicionConductor(
                    conductor.getId(),
                    persona.getNombres(),
                    persona.getApellidos(),
                    placas.get(conductor.getId()),
                    ubicacion == null ? null : latitudDe(ubicacion),
                    ubicacion == null ? null : longitudDe(ubicacion),
                    ubicacion == null || ubicacion.getRumbo() == null
                            ? null : ubicacion.getRumbo().doubleValue(),
                    ubicacion == null || ubicacion.getVelocidad() == null
                            ? null : ubicacion.getVelocidad().doubleValue(),
                    disponibilidades.getOrDefault(conductor.getId(), Disponibilidad.DESCONECTADO),
                    ubicacion == null || ubicacion.getActualizadoEn() == null
                            ? null : aInstante(ubicacion.getActualizadoEn()));
        }).toList();
    }

    /**
     * Conductores libres que el pasajero ve en su mapa: aprobados, con la app abierta (reportaron
     * su GPS hace menos de taxiuap.conductores.segundos-en-linea) y con disponibilidad DISPONIBLE.
     * Solo se expone la posicion, no los datos personales.
     */
    @Transactional(readOnly = true)
    public List<ConductorEnLineaResponse> conductoresLibres() {
        LocalDateTime limite = LocalDateTime.now().minusSeconds(segundosEnLinea);
        return listaFlota().stream()
                .filter(posicion -> posicion.disponibilidad() == Disponibilidad.DISPONIBLE)
                .filter(posicion -> posicion.latitud() != null && posicion.actualizadoEn() != null)
                .filter(posicion -> posicion.actualizadoEn().isAfter(limite.atZone(ZoneId.systemDefault()).toInstant()))
                .map(posicion -> new ConductorEnLineaResponse(
                        posicion.idConductor(), posicion.latitud(), posicion.longitud(), posicion.rumbo()))
                .toList();
    }

    private Conductor buscarConductorOperativo(Long idConductor) {
        Conductor conductor = conductorRepository.findById(idConductor)
                .orElseThrow(() -> new NegocioException("El conductor " + idConductor + " no existe"));
        if (!EstadoRegistro.A.equals(conductor.getEstadoConductor())) {
            throw new NegocioException("El conductor " + idConductor + " esta dado de baja");
        }
        if (!SituacionAprobacion.APROBADO.equals(conductor.getSituacionAprobacion())) {
            throw new NegocioException(
                    "El conductor " + idConductor + " no esta aprobado para reportar posicion");
        }
        return conductor;
    }

    private UbicacionConductor nuevaUbicacion(Conductor conductor) {
        UbicacionConductor ubicacion = new UbicacionConductor();
        ubicacion.setConductor(conductor);
        return ubicacion;
    }

    private Point crearPunto(BigDecimal latitud, BigDecimal longitud) {
        return FABRICA_GEOMETRIA.createPoint(
                new Coordinate(longitud.doubleValue(), latitud.doubleValue()));
    }

    /**
     * Anota un cambio de disponibilidad y devuelve el valor vigente.
     *
     * Si el valor no cambio no se inserta una fila: el historial es para cambios, y llenarlo en
     * cada reporte de posicion lo llenaria de ruido.
     */
    private Disponibilidad registrarDisponibilidad(Conductor conductor, Disponibilidad nueva,
            LocalDateTime ahora) {
        Optional<DisponibilidadConductor> actual = disponibilidadConductorRepository
                .findFirstByConductorIdAndEstadoDisponibilidadConductorOrderByDesdeDesc(
                        conductor.getId(), EstadoRegistro.A);
        Disponibilidad vigente = actual
                .map(DisponibilidadConductor::getDisponibilidad)
                .orElse(Disponibilidad.DESCONECTADO);
        if (nueva == null || Objects.equals(nueva, vigente)) {
            return vigente;
        }

        DisponibilidadConductor registro = new DisponibilidadConductor();
        registro.setConductor(conductor);
        registro.setDisponibilidad(nueva);
        registro.setDesde(ahora);
        registro.setEstadoDisponibilidadConductor(EstadoRegistro.A);
        disponibilidadConductorRepository.save(registro);
        return nueva;
    }

    private BigDecimal latitudDe(UbicacionConductor ubicacion) {
        Point punto = ubicacion.getUbicacion();
        return punto == null ? null : BigDecimal.valueOf(punto.getY());
    }

    private BigDecimal longitudDe(UbicacionConductor ubicacion) {
        Point punto = ubicacion.getUbicacion();
        return punto == null ? null : BigDecimal.valueOf(punto.getX());
    }

    /**
     * Las entidades guardan LocalDateTime y la API expone Instant.
     *
     * Convertir con la zona de la JVM es lo correcto: el instante se escribio interpreting el
     * LocalDateTime en esa misma zona, y al devolverlo con Z el navegador lo lee bien sin importar
     * en que zona este el administrador.
     */
    private Instant aInstante(LocalDateTime fecha) {
        return fecha == null ? null : fecha.atZone(ZoneId.systemDefault()).toInstant();
    }
}
