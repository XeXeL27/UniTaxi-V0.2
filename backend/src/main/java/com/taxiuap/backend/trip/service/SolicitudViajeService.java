package com.taxiuap.backend.trip.service;

import java.math.BigDecimal;
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
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.pricing.service.CalculoPrecioService;
import com.taxiuap.backend.pricing.enums.MetodoPago;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.trip.dto.PrecioViajeResponse;
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
    private final ViajeService viajeService;
    private final CalculoPrecioService calculoPrecioService;

    @Value("${taxiuap.comision.porcentaje:0}")
    private BigDecimal porcentajeComision;

    /** Categoria usada cuando la app no elige una: el taxi comun. */
    private static final String CATEGORIA_POR_DEFECTO = "ESTANDAR";

    @Transactional
    public SolicitudViajeResponse crear(SolicitudViajeRequest request) {
        Pasajero pasajero = buscarPasajero();
        // Pedidos simultaneos del mismo pasajero se atienden de a uno (ver PasajeroRepository.bloquear).
        pasajeroRepository.bloquear(pasajero.getId());

        // Regla de negocio 4: un pasajero solo puede tener una solicitud activa a la vez.
        boolean tieneSolicitudActiva = solicitudViajeRepository.existsByPasajeroIdAndSituacionSolicitudIn(
                pasajero.getId(), List.of(SituacionSolicitud.PENDIENTE, SituacionSolicitud.CON_OFERTAS));
        if (tieneSolicitudActiva) {
            throw new NegocioException("Ya tiene una solicitud de viaje activa");
        }
        if (viajeService.pasajeroTieneViajeActivo(pasajero.getId())) {
            throw new NegocioException("Ya tiene un viaje en curso");
        }

        CategoriaServicio categoriaServicio = resolverCategoria(request.idCategoriaServicio());
        // Con precio fijo, el precio lo pone la plataforma y no el pasajero.
        BigDecimal precioFijo = calculoPrecioService.precioFijo();

        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(categoriaServicio);
        solicitud.setOrigen(convertirAPunto(request.origenWkt()));
        solicitud.setDestino(convertirAPunto(request.destinoWkt()));
        solicitud.setOrigenDireccion(request.origenDireccion());
        solicitud.setDestinoDireccion(request.destinoDireccion());
        solicitud.setPrecioSugerido(precioFijo != null ? precioFijo : request.precioSugerido());
        solicitud.setMetodoPago(metodoPagoPermitido(request.metodoPago()));
        solicitud.setSituacionSolicitud(SituacionSolicitud.PENDIENTE);
        solicitud.setFechaSolicitud(LocalDateTime.now());
        solicitud.setEstadoSolViaje(EstadoRegistro.A);

        SolicitudViajeResponse creada = aResponse(solicitudViajeRepository.save(solicitud));
        viajeEventPublisher.publicarSolicitudNueva(creada);
        return creada;
    }

    /** Precio que se muestra antes de confirmar (pasajero) o de aceptar (conductor). */
    public PrecioViajeResponse precioVigente() {
        return new PrecioViajeResponse(calculoPrecioService.precioFijo(), "Bs", porcentajeComision);
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

        Long idPersona = conductor.getUsuario().getPersona().getId();
        return Stream.concat(
                        solicitudViajeRepository.findBySituacionSolicitud(SituacionSolicitud.PENDIENTE).stream(),
                        solicitudViajeRepository.findBySituacionSolicitud(SituacionSolicitud.CON_OFERTAS).stream())
                // Las que este conductor ya dejo (cancelo el viaje) no le vuelven a aparecer.
                .filter(s -> !ofertaViajeRepository.existsBySolicitudIdAndConductorIdAndSituacionOferta(
                        s.getId(), conductor.getId(), SituacionOferta.RECHAZADA))
                // Ni su propio pedido si la misma persona tambien es pasajero.
                .filter(s -> !s.getPasajero().getUsuario().getPersona().getId().equals(idPersona))
                // Las mas recientes primero.
                .sorted(Comparator.comparing(SolicitudViaje::getFechaSolicitud,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .map(this::aResponse)
                .toList();
    }

    private CategoriaServicio resolverCategoria(Integer idCategoriaServicio) {
        CategoriaServicio categoriaServicio = idCategoriaServicio != null
                ? categoriaServicioRepository.findById(idCategoriaServicio)
                        .orElseThrow(() -> RecursoNoEncontradoException.de("CategoriaServicio", idCategoriaServicio))
                : categoriaServicioRepository.findAll().stream()
                        .filter(categoria -> CATEGORIA_POR_DEFECTO.equalsIgnoreCase(categoria.getNombre()))
                        .filter(categoria -> categoria.getEstadoCategoriaServicio() == EstadoRegistro.A)
                        .findFirst()
                        .orElseThrow(() -> new NegocioException("No hay una categoria de servicio ESTANDAR activa"));
        if (categoriaServicio.getEstadoCategoriaServicio() != EstadoRegistro.A) {
            throw new NegocioException("La categoria de servicio no esta activa");
        }
        return categoriaServicio;
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
        BigDecimal precioFijo = calculoPrecioService.precioFijo();

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
                // Con precio fijo se muestra el que se cobrara, aunque la solicitud se haya creado antes.
                precioFijo != null ? precioFijo : solicitud.getPrecioSugerido(),
                solicitud.getSituacionSolicitud(),
                solicitud.getFechaSolicitud(),
                cantidadOfertas,
                solicitud.getMetodoPago() != null ? solicitud.getMetodoPago() : MetodoPago.EFECTIVO);
    }

    /** Por ahora el pasajero paga en efectivo o con el QR del conductor. */
    private static MetodoPago metodoPagoPermitido(MetodoPago metodoPago) {
        if (metodoPago == null) {
            return MetodoPago.EFECTIVO;
        }
        if (metodoPago != MetodoPago.EFECTIVO && metodoPago != MetodoPago.QR) {
            throw new NegocioException("Metodo de pago no disponible: " + metodoPago);
        }
        return metodoPago;
    }
}
