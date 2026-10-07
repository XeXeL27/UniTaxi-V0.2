package com.taxiuap.backend.trip.service;

import java.math.BigDecimal;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Stream;

import org.locationtech.jts.geom.Point;
import org.locationtech.jts.io.WKTWriter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.ReglasRegistro;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.identity.service.CarnetService;
import com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryService;
import com.taxiuap.backend.pricing.service.CalculoPrecioService;
import com.taxiuap.backend.pricing.enums.MetodoPago;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.pricing.dto.CotizacionViaje;
import com.taxiuap.backend.trip.dto.CotizacionViajeResponse;
import com.taxiuap.backend.trip.dto.DatosEntregaRequest;
import com.taxiuap.backend.trip.dto.PrecioViajeResponse;
import com.taxiuap.backend.trip.dto.SolicitudViajeRequest;
import com.taxiuap.backend.trip.dto.SolicitudViajeResponse;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.OfertaViaje;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.enums.SituacionOferta;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.trip.repository.OfertaViajeRepository;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.trip.repository.DatosEntregaRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;
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

    private final SolicitudViajeRepository solicitudViajeRepository;
    private final OfertaViajeRepository ofertaViajeRepository;
    private final PasajeroRepository pasajeroRepository;
    private final ConductorRepository conductorRepository;
    private final CategoriaServicioRepository categoriaServicioRepository;
    private final VehiculoRepository vehiculoRepository;
    private final DatosEntregaRepository datosEntregaRepository;
    private final DocumentoConductorService documentoConductorService;
    private final ViajeEventPublisher viajeEventPublisher;
    private final ViajeService viajeService;
    private final CalculoPrecioService calculoPrecioService;
    private final CalculoPrecioDeliveryService calculoPrecioDeliveryService;

    @Value("${taxiuap.comision.porcentaje:0}")
    private BigDecimal porcentajeComision;

    /** Categoria usada cuando la app no elige una: el taxi comun. */
    private static final String CATEGORIA_POR_DEFECTO = "ESTANDAR";
    private static final SecureRandom ALEATORIO = new SecureRandom();

    @Transactional
    public SolicitudViajeResponse crear(SolicitudViajeRequest request) {
        Pasajero pasajero = buscarPasajero();
        if (pasajero.getUsuario().getPersona().carnetObservado()) {
            throw new NegocioException("Tus datos estan en revision: podras pedir viajes cuando un administrador los apruebe");
        }
        if (CarnetService.carnetVencido(pasajero.getUsuario().getPersona())) {
            throw new NegocioException("Tu carnet venció: sube las fotos de tu carnet nuevo para pedir viajes");
        }
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
        validarDatosEntrega(categoriaServicio, request.datosEntrega());
        boolean paraOtra = request.esParaOtraPersona();
        if (paraOtra) {
            validarPasajeroTercero(categoriaServicio, request);
        }
        Point origen = PuntoDesdeWkt.convertir(request.origenWkt());
        Point destino = PuntoDesdeWkt.convertir(request.destinoWkt());
        boolean esDelivery = categoriaServicio.esDeliveryCompatible();
        boolean esCompra = request.datosEntrega() != null
                && request.datosEntrega().tipoEnvio() == TipoEnvio.COMPRA_Y_ENTREGA;
        BigDecimal precioSolicitud;
        CotizacionViaje cotizacion = null;
        if (esDelivery) {
            // El precio de ENCOMIENDA queda fijado sobre A -> B; en compra lo estima el repartidor al aceptar.
            precioSolicitud = esCompra ? null
                    : calculoPrecioDeliveryService.calcularEncomienda(origen, destino).precioServicio();
        } else {
            // Taxi: el precio lo pone la plataforma (por tramos de km, con el descuento de estudiante).
            cotizacion = calculoPrecioService.cotizar(pasajero, origen, destino);
            precioSolicitud = cotizacion.precioNormal();
        }
        boolean pagaSolicitante = paraOtra && Boolean.TRUE.equals(request.pagaSolicitante());

        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(categoriaServicio);
        solicitud.setOrigen(origen);
        solicitud.setDestino(destino);
        solicitud.setOrigenDireccion(request.origenDireccion());
        solicitud.setDestinoDireccion(request.destinoDireccion());
        solicitud.setDestinoNombrePasajero(request.destinoNombre() == null || request.destinoNombre().isBlank()
                ? null : request.destinoNombre().trim());
        solicitud.setPrecioSugerido(precioSolicitud);
        if (cotizacion != null) {
            solicitud.setDistanciaKm(cotizacion.distanciaKm());
            // El descuento de estudiante es para que viaje el estudiante: no para otra persona.
            solicitud.setDescuentoEstudiante(paraOtra ? BigDecimal.ZERO.setScale(2) : cotizacion.descuentoEstudiante());
        }
        // Quien paga desde lejos solo puede hacerlo por el QR del conductor.
        solicitud.setMetodoPago(pagaSolicitante ? MetodoPago.QR : metodoPagoPermitido(request.metodoPago()));
        solicitud.setParaOtraPersona(paraOtra);
        if (paraOtra) {
            solicitud.setNombrePasajeroTercero(request.nombrePasajeroTercero().trim().replaceAll("\\s+", " ")
                    .toUpperCase(java.util.Locale.forLanguageTag("es")));
            solicitud.setTelefonoPasajeroTercero(request.telefonoPasajeroTercero().trim());
        }
        solicitud.setPagaSolicitante(pagaSolicitante);
        solicitud.setSituacionSolicitud(SituacionSolicitud.PENDIENTE);
        solicitud.setFechaSolicitud(LocalDateTime.now());
        solicitud.setEstadoSolViaje(EstadoRegistro.A);

        solicitud = solicitudViajeRepository.save(solicitud);
        if (request.datosEntrega() != null) {
            solicitud.setDatosEntrega(datosEntregaRepository.save(crearDatosEntrega(solicitud, request.datosEntrega())));
        }
        SolicitudViajeResponse creada = aResponse(solicitud);
        viajeEventPublisher.publicarSolicitudNueva(creada.sinNombreDestino());
        return creada;
    }

    /** Precio base (primeros km) y comision, antes de elegir destino. */
    public PrecioViajeResponse precioVigente() {
        return new PrecioViajeResponse(calculoPrecioService.precioBase(), "Bs", porcentajeComision);
    }

    /**
     * Precio del viaje elegido por el pasajero, con su descuento de estudiante, antes de pedirlo. Para
     * otra persona no hay descuento: se muestra el precio normal.
     */
    public CotizacionViajeResponse cotizar(double origenLat, double origenLng, double destinoLat, double destinoLng,
            boolean paraOtraPersona) {
        Pasajero pasajero = buscarPasajero();
        Point origen = PuntoDesdeWkt.convertir(String.format(java.util.Locale.ROOT, "POINT(%.7f %.7f)", origenLng, origenLat));
        Point destino = PuntoDesdeWkt.convertir(String.format(java.util.Locale.ROOT, "POINT(%.7f %.7f)", destinoLng, destinoLat));
        CotizacionViaje cotizacion = calculoPrecioService.cotizar(pasajero, origen, destino);
        if (paraOtraPersona) {
            return new CotizacionViajeResponse(cotizacion.distanciaKm(), cotizacion.duracionMin(), cotizacion.porCalles(),
                    cotizacion.precioNormal(), BigDecimal.ZERO.setScale(2), cotizacion.precioNormal(), "Bs");
        }
        return new CotizacionViajeResponse(cotizacion.distanciaKm(), cotizacion.duracionMin(), cotizacion.porCalles(),
                cotizacion.precioNormal(), cotizacion.descuentoEstudiante(), cotizacion.precioFinal(), "Bs");
    }

    /** Viaje para otra persona: solo taxi, con el nombre y el celular de quien viaja. */
    private static void validarPasajeroTercero(CategoriaServicio categoria, SolicitudViajeRequest request) {
        if (categoria.esDeliveryCompatible()) {
            throw new NegocioException("Un pedido de entrega no se pide para otra persona");
        }
        String nombre = request.nombrePasajeroTercero();
        if (nombre == null || nombre.isBlank() || !nombre.trim().matches("[\\p{L} ]{3,150}")) {
            throw new NegocioException("Escribe el nombre de la persona que va a viajar");
        }
        String telefono = request.telefonoPasajeroTercero();
        if (telefono == null || !telefono.trim().matches(ReglasRegistro.PATRON_CELULAR)) {
            throw new NegocioException(ReglasRegistro.MENSAJE_CELULAR);
        }
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
                .filter(s -> puedeVer(conductor, s))
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

    private void validarDatosEntrega(CategoriaServicio categoria, DatosEntregaRequest datos) {
        boolean esDelivery = categoria.esDeliveryCompatible();
        if (esDelivery != (datos != null)) {
            throw new NegocioException(esDelivery
                    ? "Una solicitud DELIVERY requiere datos de entrega"
                    : "Los datos de entrega solo se permiten con la categoria DELIVERY");
        }
    }

    private DatosEntrega crearDatosEntrega(SolicitudViaje solicitud, DatosEntregaRequest request) {
        DatosEntrega datos = new DatosEntrega();
        datos.setSolicitud(solicitud);
        datos.setTipoEnvio(request.tipoEnvio());
        datos.setDescripcion(request.descripcion());
        datos.setCostoProductoEstimado(request.costoProductoEstimado());
        datos.setNombreRemitente(request.nombreRemitente());
        datos.setTelefonoRemitente(request.telefonoRemitente());
        datos.setNombreReceptor(request.nombreReceptor());
        datos.setTelefonoReceptor(request.telefonoReceptor());
        datos.setFotoPaqueteUrl(request.fotoPaqueteUrl());
        datos.setAceptaPoliticaArticulos(Boolean.TRUE.equals(request.aceptaPoliticaArticulos()));
        if (request.tipoEnvio() == TipoEnvio.ENCOMIENDA) {
            datos.setCodigoRecogida(codigo());
            String entrega;
            do {
                entrega = codigo();
            } while (entrega.equals(datos.getCodigoRecogida()));
            datos.setCodigoEntrega(entrega);
        }
        return datos;
    }

    /**
     * Cada conductor ve solo las solicitudes de la categoria de su moto: el taxista los viajes y el
     * repartidor (moto DELIVERY) las entregas que puede adelantar.
     */
    boolean puedeVer(Conductor conductor, SolicitudViaje solicitud) {
        boolean repartidor = tieneMotoDelivery(conductor.getId());
        if (!solicitud.getCategoriaServicio().esDeliveryCompatible()) return !repartidor;
        if (!repartidor) return false;
        DatosEntrega datos = solicitud.getDatosEntrega();
        return datos == null || datos.getTipoEnvio() != TipoEnvio.COMPRA_Y_ENTREGA
                || (datos.getCostoProductoEstimado() != null
                        && conductor.getLimiteAdelantoCompra() != null
                        && datos.getCostoProductoEstimado().compareTo(conductor.getLimiteAdelantoCompra()) <= 0);
    }

    boolean tieneMotoDelivery(Long idConductor) {
        return vehiculoRepository.findByConductorId(idConductor).stream()
                .filter(v -> v.getEstadoVehiculo() == EstadoRegistro.A)
                .anyMatch(Vehiculo::esMotoDelivery);
    }

    private static String codigo() {
        return String.format("%06d", ALEATORIO.nextInt(1_000_000));
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
        boolean esDelivery = solicitud.getCategoriaServicio() != null
                && solicitud.getCategoriaServicio().esDeliveryCompatible();
        boolean esCompra = solicitud.getDatosEntrega() != null
                && solicitud.getDatosEntrega().getTipoEnvio() == TipoEnvio.COMPRA_Y_ENTREGA;
        boolean precioEstimado = esDelivery && esCompra && solicitud.getPrecioSugerido() != null
                && solicitud.getDatosEntrega().getCostoProductoReal() == null;
        // Taxi: lo que se cobra (normal menos el descuento de estudiante). Delivery: su precio de servicio.
        BigDecimal precioMostrado = esDelivery ? solicitud.getPrecioSugerido() : solicitud.precioACobrar();

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
                precioMostrado,
                precioEstimado,
                solicitud.getSituacionSolicitud(),
                solicitud.getFechaSolicitud(),
                cantidadOfertas,
                solicitud.getMetodoPago() != null ? solicitud.getMetodoPago() : MetodoPago.EFECTIVO,
                // El nombre del favorito y los codigos solo se devuelven al propio pasajero.
                esDelUsuarioActual(solicitud.getPasajero()) ? solicitud.getDestinoNombrePasajero() : null,
                com.taxiuap.backend.trip.dto.DatosEntregaResponse.desde(solicitud.getDatosEntrega(),
                        esDelUsuarioActual(solicitud.getPasajero())),
                solicitud.getPrecioSugerido(),
                solicitud.getDescuentoEstudiante() != null ? solicitud.getDescuentoEstudiante() : BigDecimal.ZERO,
                solicitud.getDistanciaKm(),
                solicitud.esParaOtraPersona(),
                solicitud.getNombrePasajeroTercero(),
                // El celular de quien viaja solo lo ve quien pidio; el conductor lo recibe al aceptar (viaje).
                esDelUsuarioActual(solicitud.getPasajero()) ? solicitud.getTelefonoPasajeroTercero() : null,
                Boolean.TRUE.equals(solicitud.getPagaSolicitante()));
    }

    private static boolean esDelUsuarioActual(Pasajero pasajero) {
        return pasajero != null && UsuarioActual.obtener()
                .map(u -> u.idUsuario().equals(pasajero.getUsuario().getId()))
                .orElse(false);
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
