package com.taxiuap.backend.trip.service;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Stream;

import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.locationtech.jts.io.ParseException;
import org.locationtech.jts.io.WKTReader;
import org.locationtech.jts.io.WKTWriter;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.trip.dto.SolicitudViajeRequest;
import com.taxiuap.backend.trip.dto.SolicitudViajeResponse;
import com.taxiuap.backend.trip.entity.OfertaViaje;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.enums.SituacionOferta;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.trip.repository.OfertaViajeRepository;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.service.DocumentoConductorService;

import lombok.RequiredArgsConstructor;

/**
 * Solicitud de viaje del pasajero: creacion, consulta, cancelacion y la lista de solicitudes
 * disponibles para que los conductores oferten.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SolicitudViajeService {

    private static final int SRID_WGS84 = 4326;
    private static final GeometryFactory FABRICA_GEOMETRIA =
            new GeometryFactory(new PrecisionModel(), SRID_WGS84);

    private final SolicitudViajeRepository solicitudViajeRepository;
    private final OfertaViajeRepository ofertaViajeRepository;
    private final PasajeroRepository pasajeroRepository;
    private final ConductorRepository conductorRepository;
    private final CategoriaServicioRepository categoriaServicioRepository;
    private final DocumentoConductorService documentoConductorService;
    private final ViajeEventPublisher viajeEventPublisher;

    @Transactional
    public SolicitudViajeResponse crear(SolicitudViajeRequest request) {
        Pasajero pasajero = buscarPasajero();

        // Regla de negocio 4: un pasajero solo puede tener una solicitud activa a la vez.
        boolean tieneSolicitudActiva = solicitudViajeRepository.existsByPasajeroIdAndSituacionSolicitudIn(
                pasajero.getId(), List.of(SituacionSolicitud.PENDIENTE, SituacionSolicitud.CON_OFERTAS));
        if (tieneSolicitudActiva) {
            throw new NegocioException("Ya tiene una solicitud de viaje activa");
        }

        CategoriaServicio categoriaServicio = categoriaServicioRepository.findById(request.idCategoriaServicio())
                .orElseThrow(() -> RecursoNoEncontradoException.de("CategoriaServicio", request.idCategoriaServicio()));
        if (categoriaServicio.getEstadoCategoriaServicio() != EstadoRegistro.A) {
            throw new NegocioException("La categoria de servicio no esta activa");
        }

        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(categoriaServicio);
        solicitud.setOrigen(convertirAPunto(request.origenWkt()));
        solicitud.setDestino(convertirAPunto(request.destinoWkt()));
        solicitud.setOrigenDireccion(request.origenDireccion());
        solicitud.setDestinoDireccion(request.destinoDireccion());
        solicitud.setPrecioSugerido(request.precioSugerido());
        solicitud.setSituacionSolicitud(SituacionSolicitud.PENDIENTE);
        solicitud.setFechaSolicitud(LocalDateTime.now());
        solicitud.setEstadoSolViaje(EstadoRegistro.A);

        SolicitudViajeResponse creada = aResponse(solicitudViajeRepository.save(solicitud));
        viajeEventPublisher.publicarSolicitudNueva(creada);
        return creada;
    }

    public List<SolicitudViajeResponse> listarPropias() {
        Pasajero pasajero = buscarPasajero();
        return solicitudViajeRepository.findByPasajeroIdOrderByFechaSolicitudDesc(pasajero.getId()).stream()
                .map(this::aResponse)
                .toList();
    }

    public SolicitudViajeResponse obtenerPropia(Long id) {
        Pasajero pasajero = buscarPasajero();
        return aResponse(buscarDelPasajero(id, pasajero.getId()));
    }

    @Transactional
    public void cancelar(Long id) {
        Pasajero pasajero = buscarPasajero();
        SolicitudViaje solicitud = buscarDelPasajero(id, pasajero.getId());

        if (solicitud.getSituacionSolicitud() != SituacionSolicitud.PENDIENTE
                && solicitud.getSituacionSolicitud() != SituacionSolicitud.CON_OFERTAS) {
            throw new NegocioException("La solicitud ya no se puede cancelar");
        }

        solicitud.setSituacionSolicitud(SituacionSolicitud.CANCELADA);
        solicitudViajeRepository.save(solicitud);

        List<OfertaViaje> ofertasPendientes = ofertaViajeRepository
                .findBySolicitudIdAndSituacionOferta(id, SituacionOferta.PENDIENTE);
        ofertasPendientes.forEach(oferta -> oferta.setSituacionOferta(SituacionOferta.RECHAZADA));
        ofertaViajeRepository.saveAll(ofertasPendientes);

        viajeEventPublisher.publicarSolicitudCerrada(id, "Solicitud cancelada por el pasajero");
    }

    /**
     * Solicitudes que un conductor puede ver para ofertar. Esta es la puerta de las reglas de
     * negocio 1 y 2: antes de mostrar cualquier solicitud se exige que el conductor este APROBADO
     * y con todos sus documentos vigentes y aprobados (DocumentoConductorService.puedeOperar).
     */
    public List<SolicitudViajeResponse> listarDisponiblesParaConductor() {
        Conductor conductor = buscarConductor();
        if (!documentoConductorService.puedeOperar(conductor.getId())) {
            throw new NegocioException("El conductor no esta habilitado para recibir solicitudes");
        }

        return Stream.concat(
                        solicitudViajeRepository.findBySituacionSolicitud(SituacionSolicitud.PENDIENTE).stream(),
                        solicitudViajeRepository.findBySituacionSolicitud(SituacionSolicitud.CON_OFERTAS).stream())
                .sorted(Comparator.comparing(SolicitudViaje::getFechaSolicitud))
                .map(this::aResponse)
                .toList();
    }

    private Pasajero buscarPasajero() {
        return pasajeroRepository.findByUsuarioId(UsuarioActual.idUsuario())
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de pasajero"));
    }

    private Conductor buscarConductor() {
        return conductorRepository.findByUsuarioId(UsuarioActual.idUsuario())
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de conductor"));
    }

    private SolicitudViaje buscarDelPasajero(Long id, Long idPasajero) {
        SolicitudViaje solicitud = solicitudViajeRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("SolicitudViaje", id));
        if (solicitud.getPasajero() == null || !solicitud.getPasajero().getId().equals(idPasajero)) {
            throw RecursoNoEncontradoException.de("SolicitudViaje", id);
        }
        return solicitud;
    }

    private Point convertirAPunto(String wkt) {
        try {
            Geometry geometria = new WKTReader(FABRICA_GEOMETRIA).read(wkt);
            if (!(geometria instanceof Point punto)) {
                throw new NegocioException("La ubicacion no es un WKT valido de tipo POINT");
            }
            return punto;
        } catch (ParseException excepcion) {
            throw new NegocioException("La ubicacion no es un WKT valido de tipo POINT");
        }
    }

    private SolicitudViajeResponse aResponse(SolicitudViaje solicitud) {
        String nombrePasajero = solicitud.getPasajero() != null && solicitud.getPasajero().getUsuario() != null
                && solicitud.getPasajero().getUsuario().getPersona() != null
                        ? solicitud.getPasajero().getUsuario().getPersona().getNombres() + " "
                                + solicitud.getPasajero().getUsuario().getPersona().getApellidos()
                        : null;
        String nombreCategoriaServicio = solicitud.getCategoriaServicio() != null
                ? solicitud.getCategoriaServicio().getNombre()
                : null;
        String origenWkt = solicitud.getOrigen() != null ? new WKTWriter().write(solicitud.getOrigen()) : null;
        String destinoWkt = solicitud.getDestino() != null ? new WKTWriter().write(solicitud.getDestino()) : null;
        int cantidadOfertas = ofertaViajeRepository.findBySolicitudIdAndSituacionOferta(
                solicitud.getId(), SituacionOferta.PENDIENTE).size();

        return new SolicitudViajeResponse(
                solicitud.getId(),
                solicitud.getPasajero() != null ? solicitud.getPasajero().getId() : null,
                nombrePasajero,
                solicitud.getCategoriaServicio() != null ? solicitud.getCategoriaServicio().getId() : null,
                nombreCategoriaServicio,
                origenWkt,
                destinoWkt,
                solicitud.getOrigenDireccion(),
                solicitud.getDestinoDireccion(),
                solicitud.getPrecioSugerido(),
                solicitud.getSituacionSolicitud(),
                solicitud.getFechaSolicitud(),
                cantidadOfertas);
    }
}
