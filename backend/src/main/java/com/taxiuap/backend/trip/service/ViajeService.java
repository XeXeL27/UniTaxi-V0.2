package com.taxiuap.backend.trip.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.locationtech.jts.io.WKTWriter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.pricing.dto.CalculoPrecio;
import com.taxiuap.backend.pricing.entity.BilleteraConductor;
import com.taxiuap.backend.pricing.entity.Comision;
import com.taxiuap.backend.pricing.entity.Pago;
import com.taxiuap.backend.pricing.enums.MetodoPago;
import com.taxiuap.backend.pricing.enums.SituacionPago;
import com.taxiuap.backend.pricing.repository.BilleteraConductorRepository;
import com.taxiuap.backend.pricing.repository.ComisionRepository;
import com.taxiuap.backend.pricing.repository.PagoRepository;
import com.taxiuap.backend.rating.repository.CalificacionRepository;
import com.taxiuap.backend.pricing.service.CalculoPrecioService;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.trip.dto.CancelarViajeRequest;
import com.taxiuap.backend.trip.dto.FinalizarViajeRequest;
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.entity.OfertaViaje;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.CanceladoPor;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.repository.ViajeRepository;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Ciclo de vida del viaje: alta a partir de una oferta aceptada, cambios de situacion y
 * finalizacion con pago, comision y actualizacion de billetera (regla de negocio 7).
 */
@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class ViajeService {

    /** Situaciones finales de un viaje: ya no hay nada activo que mostrar como "en curso". */
    private static final List<SituacionViaje> ESTADOS_FINALES =
            List.of(SituacionViaje.COMPLETADO, SituacionViaje.CANCELADO);

    private final ViajeRepository viajeRepository;
    private final PasajeroRepository pasajeroRepository;
    private final ConductorRepository conductorRepository;
    private final VehiculoRepository vehiculoRepository;
    private final PagoRepository pagoRepository;
    private final ComisionRepository comisionRepository;
    private final BilleteraConductorRepository billeteraConductorRepository;
    private final CalculoPrecioService calculoPrecioService;
    private final HistorialViajeService historialViajeService;
    private final SimpMessagingTemplate mensajeriaTemplate;
    private final CalificacionRepository calificacionRepository;

    @Value("${taxiuap.comision.porcentaje:15}")
    private BigDecimal porcentajeComision;

    /**
     * Crea el viaje a partir de una solicitud y su oferta aceptada. Se anota con propagacion
     * MANDATORY a proposito: este metodo solo debe correr dentro de la transaccion atomica de
     * aceptacion de la oferta (OfertaViajeService.aceptar), nunca en una propia. Si la creacion
     * del viaje falla, toda la aceptacion de la oferta se deshace junto con ella.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public Viaje crearDesdeOferta(SolicitudViaje solicitud, OfertaViaje oferta) {
        Conductor conductor = oferta.getConductor();
        Vehiculo vehiculo = vehiculoRepository.findByConductorId(conductor.getId()).stream()
                .filter(v -> v.getEstadoVehiculo() == EstadoRegistro.A)
                .findFirst()
                .orElseThrow(() -> new NegocioException("El conductor no tiene un vehiculo registrado"));

        Pasajero pasajero = solicitud.getPasajero();
        CalculoPrecio calculo = calculoPrecioService.calcular(solicitud, oferta, pasajero);

        Viaje viaje = new Viaje();
        viaje.setSolicitud(solicitud);
        viaje.setPasajero(pasajero);
        viaje.setConductor(conductor);
        viaje.setVehiculo(vehiculo);
        viaje.setCategoriaServicio(solicitud.getCategoriaServicio());
        viaje.setTarifa(calculo.tarifa());
        viaje.setOrigen(solicitud.getOrigen());
        viaje.setDestino(solicitud.getDestino());
        viaje.setDistanciaKm(calculo.distanciaKm());
        viaje.setDuracionMin(calculo.duracionMin());
        viaje.setPrecioOriginal(calculo.precioOriginal());
        viaje.setMontoDescuento(calculo.montoDescuento());
        viaje.setPrecioFinal(calculo.precioFinal());
        viaje.setSituacionViaje(SituacionViaje.CONFIRMADO);

        // Solo se deja constancia del estudiante y la regla cuando realmente hubo descuento.
        if (calculo.montoDescuento().compareTo(BigDecimal.ZERO) > 0) {
            viaje.setEstudiante(calculo.estudiante());
            viaje.setReglaDescuento(calculo.regla());
        }

        viaje = viajeRepository.save(viaje);

        // Regla de negocio 6: cada cambio de situacion se registra en el historial, incluido el alta.
        historialViajeService.registrar(viaje, SituacionViaje.CONFIRMADO, pasajero.getUsuario().getId());

        return viaje;
    }

    @Transactional
    public ViajeResponse enCamino(Long idViaje) {
        Viaje viaje = obtenerViajeDelConductor(idViaje);
        validarTransicion(viaje, SituacionViaje.CONFIRMADO, SituacionViaje.CONDUCTOR_EN_CAMINO);
        viaje = viajeRepository.save(viaje);
        return registrarYNotificar(viaje);
    }

    @Transactional
    public ViajeResponse llegue(Long idViaje) {
        Viaje viaje = obtenerViajeDelConductor(idViaje);
        validarTransicion(viaje, SituacionViaje.CONDUCTOR_EN_CAMINO, SituacionViaje.CONDUCTOR_LLEGO);
        viaje = viajeRepository.save(viaje);
        return registrarYNotificar(viaje);
    }

    @Transactional
    public ViajeResponse iniciar(Long idViaje) {
        Viaje viaje = obtenerViajeDelConductor(idViaje);
        validarTransicion(viaje, SituacionViaje.CONDUCTOR_LLEGO, SituacionViaje.EN_CURSO);
        viaje.setFechaInicio(LocalDateTime.now());
        viaje = viajeRepository.save(viaje);
        return registrarYNotificar(viaje);
    }

    @Transactional
    public ViajeResponse finalizar(Long idViaje, FinalizarViajeRequest request) {
        Viaje viaje = obtenerViajeDelConductor(idViaje);
        validarTransicion(viaje, SituacionViaje.EN_CURSO, SituacionViaje.COMPLETADO);
        viaje.setFechaFin(LocalDateTime.now());
        // La solicitud que origino el viaje queda cerrada como FINALIZADA (entidad administrada:
        // se guarda con la transaccion).
        viaje.getSolicitud().setSituacionSolicitud(SituacionSolicitud.FINALIZADA);
        viaje = viajeRepository.save(viaje);

        // Regla de negocio 7: al completar el viaje se crea el pago, la comision y se actualiza
        // la billetera del conductor, todo dentro de esta misma transaccion.
        procesarPagoYComision(viaje, request.metodoPago());

        return registrarYNotificar(viaje);
    }

    @Transactional
    public ViajeResponse cancelar(Long idViaje, CancelarViajeRequest request) {
        Long idUsuario = UsuarioActual.idUsuario();
        Viaje viaje = obtenerViaje(idViaje);
        CanceladoPor canceladoPor = resolverCancelador(viaje, idUsuario);

        boolean sePuedeCancelar = viaje.getSituacionViaje() == SituacionViaje.CONFIRMADO
                || viaje.getSituacionViaje() == SituacionViaje.CONDUCTOR_EN_CAMINO
                || viaje.getSituacionViaje() == SituacionViaje.CONDUCTOR_LLEGO;
        if (!sePuedeCancelar) {
            throw new NegocioException("El viaje ya no se puede cancelar");
        }

        viaje.setSituacionViaje(SituacionViaje.CANCELADO);
        viaje.setCanceladoPor(canceladoPor);
        viaje.getSolicitud().setSituacionSolicitud(SituacionSolicitud.CANCELADA);
        viaje = viajeRepository.save(viaje);

        return registrarYNotificar(viaje);
    }

    public List<ViajeResponse> listarDelPasajero() {
        Pasajero pasajero = obtenerPasajeroActual();
        return viajeRepository.findByPasajeroIdOrderByFechaInicioDesc(pasajero.getId()).stream()
                .map(this::aRespuesta)
                .toList();
    }

    public List<ViajeResponse> listarDelConductor() {
        Conductor conductor = obtenerConductorActual();
        return viajeRepository.findByConductorIdOrderByFechaInicioDesc(conductor.getId()).stream()
                .map(this::aRespuesta)
                .toList();
    }

    /** Viajes de un conductor, del mas reciente al mas antiguo (panel admin). */
    public List<ViajeResponse> listarPorConductor(Long idConductor) {
        return viajeRepository.findByConductorIdOrderByFechaInicioDesc(idConductor).stream()
                .map(this::aRespuesta)
                .toList();
    }

    /** Viajes de un pasajero, del mas reciente al mas antiguo (panel admin). */
    public List<ViajeResponse> listarPorPasajero(Long idPasajero) {
        return viajeRepository.findByPasajeroIdOrderByFechaInicioDesc(idPasajero).stream()
                .map(this::aRespuesta)
                .toList();
    }

    public ViajeResponse obtener(Long idViaje) {
        Long idUsuario = UsuarioActual.idUsuario();
        Viaje viaje = obtenerViaje(idViaje);
        boolean esParte = viaje.getPasajero().getUsuario().getId().equals(idUsuario)
                || viaje.getConductor().getUsuario().getId().equals(idUsuario);
        if (!esParte) {
            throw RecursoNoEncontradoException.de("Viaje", idViaje);
        }
        return aRespuesta(viaje);
    }

    /**
     * Lectura directa por id, sin validar que el que llama sea parte del viaje. La usa
     * OfertaViajeService.aceptar() justo despues de crearDesdeOferta, dentro de la misma
     * transaccion, para devolver la respuesta al pasajero que acepto la oferta.
     */
    public ViajeResponse obtenerPorId(Long idViaje) {
        return aRespuesta(obtenerViaje(idViaje));
    }

    /** Viaje activo (no finalizado ni cancelado) del pasajero o conductor autenticado, si tiene uno. */
    public Optional<ViajeResponse> enCurso() {
        Long idUsuario = UsuarioActual.idUsuario();

        Optional<Pasajero> pasajeroOpt = pasajeroRepository.findByUsuarioId(idUsuario);
        if (pasajeroOpt.isPresent()) {
            return viajeRepository
                    .findFirstByPasajeroIdAndSituacionViajeNotIn(pasajeroOpt.get().getId(), ESTADOS_FINALES)
                    .map(this::aRespuesta);
        }

        Optional<Conductor> conductorOpt = conductorRepository.findByUsuarioId(idUsuario);
        if (conductorOpt.isPresent()) {
            return viajeRepository
                    .findFirstByConductorIdAndSituacionViajeNotIn(conductorOpt.get().getId(), ESTADOS_FINALES)
                    .map(this::aRespuesta);
        }

        return Optional.empty();
    }

    /** true si el pasajero tiene un viaje asignado que todavia no termino ni se cancelo. */
    public boolean pasajeroTieneViajeActivo(Long idPasajero) {
        return viajeRepository.findFirstByPasajeroIdAndSituacionViajeNotIn(idPasajero, ESTADOS_FINALES).isPresent();
    }

    /** true si el conductor tiene un viaje asignado que todavia no termino ni se cancelo. */
    public boolean conductorTieneViajeActivo(Long idConductor) {
        return viajeRepository.findFirstByConductorIdAndSituacionViajeNotIn(idConductor, ESTADOS_FINALES).isPresent();
    }

    /** Convierte la entidad Viaje en su respuesta publica. La usa tambien OfertaViajeService al aceptar. */
    public ViajeResponse aRespuesta(Viaje viaje) {
        Usuario usuarioPasajero = viaje.getPasajero().getUsuario();
        Usuario usuarioConductor = viaje.getConductor().getUsuario();
        WKTWriter escritorWkt = new WKTWriter();

        return new ViajeResponse(
                viaje.getId(),
                viaje.getSolicitud().getId(),
                viaje.getPasajero().getId(),
                usuarioPasajero.getPersona().getNombres() + " " + usuarioPasajero.getPersona().getApellidos(),
                viaje.getConductor().getId(),
                usuarioConductor.getPersona().getNombres() + " " + usuarioConductor.getPersona().getApellidos(),
                viaje.getVehiculo().getPlaca(),
                viaje.getVehiculo().getMarca(),
                viaje.getVehiculo().getModelo(),
                viaje.getVehiculo().getColor(),
                viaje.getConductor().getCalificacionPromedio(),
                escritorWkt.write(viaje.getOrigen()),
                escritorWkt.write(viaje.getDestino()),
                viaje.getSolicitud().getOrigenDireccion(),
                viaje.getSolicitud().getDestinoDireccion(),
                viaje.getDistanciaKm(),
                viaje.getDuracionMin(),
                viaje.getPrecioOriginal(),
                viaje.getMontoDescuento(),
                viaje.getPrecioFinal(),
                viaje.getSituacionViaje(),
                viaje.getCanceladoPor(),
                viaje.getFechaInicio(),
                viaje.getFechaFin(),
                calificacionRepository.existsByViajeIdAndUsuarioEmisorId(viaje.getId(), usuarioPasajero.getId()));
    }

    /**
     * Regla de negocio 7: crea el pago (COMPLETADO si es en efectivo, PENDIENTE en otro caso) y
     * la comision de la plataforma, y actualiza la billetera del conductor segun el metodo de pago.
     */
    private void procesarPagoYComision(Viaje viaje, MetodoPago metodoPago) {
        LocalDateTime ahora = LocalDateTime.now();

        Pago pago = new Pago();
        pago.setViaje(viaje);
        pago.setMetodoPago(metodoPago);
        pago.setMonto(viaje.getPrecioFinal().setScale(2, RoundingMode.HALF_UP));
        pago.setSituacionPago(metodoPago == MetodoPago.EFECTIVO ? SituacionPago.COMPLETADO : SituacionPago.PENDIENTE);
        pago.setFechaPago(ahora);
        pagoRepository.save(pago);

        BigDecimal montoComision = viaje.getPrecioFinal()
                .multiply(porcentajeComision)
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);

        Comision comision = new Comision();
        comision.setViaje(viaje);
        comision.setPorcentaje(porcentajeComision);
        comision.setMonto(montoComision);
        comisionRepository.save(comision);

        BilleteraConductor billetera = billeteraConductorRepository.findByConductorId(viaje.getConductor().getId())
                .orElseThrow(() -> RecursoNoEncontradoException.de("BilleteraConductor", viaje.getConductor().getId()));

        if (metodoPago == MetodoPago.EFECTIVO) {
            // El conductor ya cobro el viaje en mano: le queda pendiente pagar la comision a la plataforma.
            billetera.setDeudaComision(
                    billetera.getDeudaComision().add(montoComision).setScale(2, RoundingMode.HALF_UP));
        } else {
            // El pago paso por la plataforma (QR/tarjeta): se le acredita el neto (precio final menos comision).
            BigDecimal neto = viaje.getPrecioFinal().subtract(montoComision);
            billetera.setSaldo(billetera.getSaldo().add(neto).setScale(2, RoundingMode.HALF_UP));
        }
        billetera.setActualizadoEn(ahora);
        billeteraConductorRepository.save(billetera);
    }

    private void validarTransicion(Viaje viaje, SituacionViaje esperado, SituacionViaje nuevo) {
        if (viaje.getSituacionViaje() != esperado) {
            throw new NegocioException(
                    "Transicion de estado no permitida: " + viaje.getSituacionViaje() + " -> " + nuevo);
        }
        viaje.setSituacionViaje(nuevo);
    }

    private CanceladoPor resolverCancelador(Viaje viaje, Long idUsuario) {
        boolean esPasajero = viaje.getPasajero().getUsuario().getId().equals(idUsuario);
        boolean esConductor = viaje.getConductor().getUsuario().getId().equals(idUsuario);
        if (!esPasajero && !esConductor) {
            throw RecursoNoEncontradoException.de("Viaje", viaje.getId());
        }
        return esPasajero ? CanceladoPor.PASAJERO : CanceladoPor.CONDUCTOR;
    }

    private ViajeResponse registrarYNotificar(Viaje viaje) {
        historialViajeService.registrar(viaje, viaje.getSituacionViaje(), UsuarioActual.idUsuario());
        ViajeResponse respuesta = aRespuesta(viaje);
        notificarCambio(viaje, respuesta);
        return respuesta;
    }

    // TODO: unificar con ViajeEventPublisher (trip/service) cuando el flujo de solicitud/oferta
    // y el flujo de viaje compartan un unico publicador de eventos en tiempo real.
    private void notificarCambio(Viaje viaje, ViajeResponse respuesta) {
        notificarUsuario(viaje.getPasajero().getUsuario().getId(), respuesta);
        notificarUsuario(viaje.getConductor().getUsuario().getId(), respuesta);
    }

    private void notificarUsuario(Long idUsuario, ViajeResponse respuesta) {
        try {
            mensajeriaTemplate.convertAndSendToUser(String.valueOf(idUsuario), "/queue/viajes", respuesta);
        } catch (Exception excepcion) {
            // Un fallo de WebSocket nunca debe tumbar la transaccion del viaje.
            log.warn("No se pudo notificar por WebSocket el cambio de viaje {} al usuario {}",
                    respuesta.idViaje(), idUsuario, excepcion);
        }
    }

    private Viaje obtenerViajeDelConductor(Long idViaje) {
        Conductor conductor = conductorRepository.findByUsuarioId(UsuarioActual.idUsuario())
                .orElseThrow(() -> RecursoNoEncontradoException.de("Viaje", idViaje));
        Viaje viaje = obtenerViaje(idViaje);
        if (!viaje.getConductor().getId().equals(conductor.getId())) {
            throw RecursoNoEncontradoException.de("Viaje", idViaje);
        }
        return viaje;
    }

    private Viaje obtenerViaje(Long idViaje) {
        return viajeRepository.findById(idViaje)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Viaje", idViaje));
    }

    private Pasajero obtenerPasajeroActual() {
        return pasajeroRepository.findByUsuarioId(UsuarioActual.idUsuario())
                .orElseThrow(() -> new NegocioException("El usuario autenticado no es un pasajero"));
    }

    private Conductor obtenerConductorActual() {
        return conductorRepository.findByUsuarioId(UsuarioActual.idUsuario())
                .orElseThrow(() -> new NegocioException("El usuario autenticado no es un conductor"));
    }
}
