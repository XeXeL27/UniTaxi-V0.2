package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.Optional;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import com.taxiuap.backend.communication.service.NotificacionPushService;
import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.location.repository.UbicacionConductorRepository;
import com.taxiuap.backend.pricing.entity.Tarifa;
import com.taxiuap.backend.pricing.repository.BilleteraConductorRepository;
import com.taxiuap.backend.pricing.repository.ComisionRepository;
import com.taxiuap.backend.pricing.repository.PagoRepository;
import com.taxiuap.backend.pricing.repository.TarifaRepository;
import com.taxiuap.backend.pricing.repository.ReglaDescuentoEstudiantilRepository;
import com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryService;
import com.taxiuap.backend.pricing.service.CalculoPrecioService;
import com.taxiuap.backend.pricing.service.QrPagoConductorService;
import com.taxiuap.backend.rating.repository.CalificacionRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.dto.CancelarViajeRequest;
import com.taxiuap.backend.trip.dto.FinalizarViajeRequest;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.OfertaViaje;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.CanceladoPor;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.trip.repository.DatosEntregaRepository;
import com.taxiuap.backend.trip.repository.OfertaViajeRepository;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.trip.repository.ViajeRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

/**
 * El viaje DELIVERY no avanza con las acciones genericas de taxi: las transiciones las protege
 * EntregaService. Aqui se fija que al aceptar el pedido pasa a EN_CAMINO_RECOGIDA, que
 * iniciar/finalizar genericos quedan rechazados y que con el pedido en mano el cliente ya no
 * puede cancelar.
 */
@ExtendWith(MockitoExtension.class)
class ViajeServiceEntregaTransicionesTest {

    private static final GeometryFactory GEOMETRIA = new GeometryFactory(new PrecisionModel(), 4326);

    @Mock private ViajeRepository viajeRepository;
    @Mock private PasajeroRepository pasajeroRepository;
    @Mock private ConductorRepository conductorRepository;
    @Mock private VehiculoRepository vehiculoRepository;
    @Mock private PagoRepository pagoRepository;
    @Mock private ComisionRepository comisionRepository;
    @Mock private BilleteraConductorRepository billeteraConductorRepository;
    @Mock private HistorialViajeService historialViajeService;
    @Mock private SimpMessagingTemplate mensajeriaTemplate;
    @Mock private CalificacionRepository calificacionRepository;
    @Mock private QrPagoConductorService qrPagoConductorService;
    @Mock private SolicitudViajeRepository solicitudViajeRepository;
    @Mock private DatosEntregaRepository datosEntregaRepository;
    @Mock private OfertaViajeRepository ofertaViajeRepository;
    @Mock private UbicacionConductorRepository ubicacionConductorRepository;
    @Mock private NotificacionPushService notificacionPushService;
    @Mock private CalculoPrecioDeliveryService calculoPrecioDeliveryService;

    @Mock private TarifaRepository tarifaRepository;
    @Mock private ReglaDescuentoEstudiantilRepository reglaDescuentoRepository;

    private ViajeService viajeService;
    private CategoriaServicio delivery;
    private Pasajero pasajero;
    private Conductor conductor;
    private Vehiculo motoDelivery;

    @BeforeEach
    void setUp() {
        TipoVehiculo tipoMoto = new TipoVehiculo();
        tipoMoto.setCodigo("MOTO");
        delivery = new CategoriaServicio();
        delivery.setId(7);
        delivery.setNombre("DELIVERY");
        delivery.setTipoVehiculo(tipoMoto);

        pasajero = new Pasajero();
        pasajero.setId(30L);
        pasajero.setUsuario(usuario(10L, "Pasajera"));
        conductor = new Conductor();
        conductor.setId(40L);
        conductor.setUsuario(usuario(20L, "Repartidor"));

        motoDelivery = new Vehiculo();
        motoDelivery.setId(2L);
        motoDelivery.setEstadoVehiculo(EstadoRegistro.A);
        motoDelivery.setCategoriaServicio(delivery);
        motoDelivery.setTipoVehiculo(tipoMoto);

        viajeService = new ViajeService(viajeRepository, pasajeroRepository, conductorRepository,
                vehiculoRepository, pagoRepository, comisionRepository, billeteraConductorRepository,
                mockCalculoPrecioService(), calculoPrecioDeliveryService, historialViajeService,
                mensajeriaTemplate, calificacionRepository, qrPagoConductorService, solicitudViajeRepository,
                datosEntregaRepository, ofertaViajeRepository, ubicacionConductorRepository,
                notificacionPushService);
    }

    @AfterEach
    void limpiarSeguridad() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void alAceptarElViajeDeliveryElPedidoPasaACaminoRecogida() {
        SolicitudViaje solicitud = solicitudEncomienda();
        OfertaViaje oferta = new OfertaViaje();
        oferta.setSolicitud(solicitud);
        oferta.setConductor(conductor);
        when(vehiculoRepository.findByConductorId(40L)).thenReturn(java.util.List.of(motoDelivery));
        when(viajeRepository.save(any(Viaje.class))).thenAnswer(invocacion -> {
            Viaje viaje = invocacion.getArgument(0);
            viaje.setId(500L);
            return viaje;
        });

        viajeService.crearDesdeOferta(solicitud, oferta);

        assertEquals(EstadoEntrega.EN_CAMINO_RECOGIDA, solicitud.getDatosEntrega().getEstadoEntrega());
    }

    @Test
    void iniciarGenericoNoAvanzaUnViajeDelivery() {
        Viaje viaje = viajeDelivery(SituacionViaje.CONDUCTOR_LLEGO, EstadoEntrega.EN_CAMINO_RECOGIDA);
        when(conductorRepository.findByUsuarioId(20L)).thenReturn(Optional.of(conductor));
        when(viajeRepository.findById(500L)).thenReturn(Optional.of(viaje));
        autenticarConductor();

        assertThrows(NegocioException.class, () -> viajeService.iniciar(500L));

        assertEquals(SituacionViaje.CONDUCTOR_LLEGO, viaje.getSituacionViaje());
        verify(viajeRepository, never()).save(any(Viaje.class));
    }

    @Test
    void finalizarGenericoNoAvanzaUnViajeDelivery() {
        Viaje viaje = viajeDelivery(SituacionViaje.EN_CURSO, EstadoEntrega.EN_MANO);
        when(conductorRepository.findByUsuarioId(20L)).thenReturn(Optional.of(conductor));
        when(viajeRepository.findById(500L)).thenReturn(Optional.of(viaje));
        autenticarConductor();

        assertThrows(NegocioException.class, () -> viajeService.finalizar(500L, FinalizarViajeRequest.sinDatos()));

        assertEquals(SituacionViaje.EN_CURSO, viaje.getSituacionViaje());
        verify(pagoRepository, never()).save(any());
    }

    @Test
    void elPasajeroNoPuedeCancelarConElPedidoEnMano() {
        Viaje viaje = viajeDelivery(SituacionViaje.EN_CURSO, EstadoEntrega.EN_MANO);
        when(viajeRepository.findById(500L)).thenReturn(Optional.of(viaje));
        autenticarPasajero();

        NegocioException error = assertThrows(NegocioException.class, () -> viajeService.cancelar(500L, null));

        assertEquals(true, error.getMessage().contains("en manos del repartidor"));
        assertEquals(SituacionViaje.EN_CURSO, viaje.getSituacionViaje());
        verify(viajeRepository, never()).save(any(Viaje.class));
    }

    @Test
    void laFallaDeEntregaCancelaSinRepublicarElPedido() {
        Viaje viaje = viajeDelivery(SituacionViaje.EN_CURSO, EstadoEntrega.EN_MANO);
        when(conductorRepository.findByUsuarioId(20L)).thenReturn(Optional.of(conductor));
        when(viajeRepository.findById(500L)).thenReturn(Optional.of(viaje));
        when(viajeRepository.save(any(Viaje.class))).thenAnswer(invocacion -> invocacion.getArgument(0));
        autenticarConductor();

        viajeService.cancelarFallaEntrega(500L);

        assertEquals(SituacionViaje.CANCELADO, viaje.getSituacionViaje());
        assertEquals(CanceladoPor.CONDUCTOR, viaje.getCanceladoPor());
        // No se republica: es un incidente para el admin, no un pedido que otro repartidor pueda tomar.
        verify(solicitudViajeRepository, never()).save(any(SolicitudViaje.class));
        verify(ofertaViajeRepository, never()).save(any(OfertaViaje.class));
    }

    @Test
    void laCancelacionTempranaDelClienteNoRepublicaNiCobraNada() {
        Viaje viaje = viajeDelivery(SituacionViaje.CONFIRMADO, EstadoEntrega.PENDIENTE_RECOGIDA);
        when(viajeRepository.findById(500L)).thenReturn(Optional.of(viaje));
        when(viajeRepository.save(any(Viaje.class))).thenAnswer(invocacion -> invocacion.getArgument(0));
        autenticarPasajero();

        viajeService.cancelar(500L, new CancelarViajeRequest("Me equivoque de direccion"));

        assertEquals(SituacionViaje.CANCELADO, viaje.getSituacionViaje());
        assertEquals(CanceladoPor.PASAJERO, viaje.getCanceladoPor());
        // Cancelacion temprana no genera compensacion ni republicacion.
        verify(pagoRepository, never()).save(any());
        verify(solicitudViajeRepository, never()).save(any(SolicitudViaje.class));
    }

    @Test
    void laCancelacionTempranaDelRepartidorRepublicaElPedidoSinLoQueElHizo() {
        Viaje viaje = viajeDelivery(SituacionViaje.CONFIRMADO, EstadoEntrega.EN_CAMINO_RECOGIDA);
        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        // El repartidor ya habia propuso una compra y habia cobrado: nada de eso viaja al nuevo pedido.
        datos.setDetalleCompraPropuesto("Farmacia Central");
        datos.setPuntoCompraPropuesto(punto(-68.745, -11.025));
        datos.setCostoProductoConfirmado(new BigDecimal("25.00"));
        datos.setCompraConfirmadaPorCliente(true);
        datos.setCostoProductoReal(new BigDecimal("25.00"));
        datos.setPagoConfirmado(true);
        datos.setMontoPagoRecibido(new BigDecimal("42.50"));
        datos.setFotoComprobanteUrl("personas/20_x/entrega/comprobante_1.jpg");

        when(viajeRepository.findById(500L)).thenReturn(Optional.of(viaje));
        when(viajeRepository.save(any(Viaje.class))).thenAnswer(invocacion -> invocacion.getArgument(0));
        when(solicitudViajeRepository.save(any(SolicitudViaje.class)))
                .thenAnswer(invocacion -> {
                    SolicitudViaje guardada = invocacion.getArgument(0);
                    guardada.setId(91L);
                    return guardada;
                });
        autenticarConductor();

        viajeService.cancelar(500L, new CancelarViajeRequest("No puedo atender"));

        ArgumentCaptor<DatosEntrega> republicado = ArgumentCaptor.forClass(DatosEntrega.class);
        verify(datosEntregaRepository).save(republicado.capture());
        DatosEntrega datosNuevos = republicado.getValue();
        // Los codigos y el comercio propuesto se conservan: es el mismo pedido.
        assertEquals("123456", datosNuevos.getCodigoRecogida());
        assertEquals("654321", datosNuevos.getCodigoEntrega());
        assertEquals("Farmacia Central", datosNuevos.getDetalleCompraPropuesto());
        assertEquals(EstadoEntrega.PENDIENTE_RECOGIDA, datosNuevos.getEstadoEntrega());
        // Lo que hizo el repartidor que cancelo, no.
        assertEquals(false, datosNuevos.getCompraConfirmadaPorCliente());
        assertEquals(null, datosNuevos.getCostoProductoReal());
        assertEquals(false, datosNuevos.getPagoConfirmado());
        assertEquals(null, datosNuevos.getMontoPagoRecibido());
        assertEquals(null, datosNuevos.getFotoComprobanteUrl());
        assertEquals(null, datosNuevos.getCostoProductoConfirmado());
        verify(pagoRepository, never()).save(any());
    }

    private CalculoPrecioService mockCalculoPrecioService() {
        CalculoPrecioService servicio = org.mockito.Mockito.mock(CalculoPrecioService.class);
        Tarifa tarifa = new Tarifa();
        tarifa.setCategoriaServicio(delivery);
        tarifa.setTarifaBase(BigDecimal.ZERO);
        tarifa.setPrecioKm(BigDecimal.ZERO);
        tarifa.setPrecioMinuto(BigDecimal.ZERO);
        tarifa.setTarifaMinima(BigDecimal.ZERO);
        tarifa.setEstadoTarifa(EstadoRegistro.A);
        // Solo la aceptacion del pedido llega a cotizar; el resto de pruebas no deben fallar por un
        // stub que no se usa.
        org.mockito.Mockito.lenient().when(servicio.tarifaVigente(any())).thenReturn(tarifa);
        return servicio;
    }

    private SolicitudViaje solicitudEncomienda() {
        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setId(90L);
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(delivery);
        solicitud.setOrigen(punto(-68.75, -11.02));
        solicitud.setDestino(punto(-68.74, -11.03));
        solicitud.setPrecioSugerido(new BigDecimal("17.50"));

        DatosEntrega datos = new DatosEntrega();
        datos.setSolicitud(solicitud);
        datos.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        datos.setDescripcion("Documentos");
        datos.setCostoProductoEstimado(BigDecimal.ZERO);
        datos.setCodigoRecogida("123456");
        datos.setCodigoEntrega("654321");
        datos.setAceptaPoliticaArticulos(true);
        solicitud.setDatosEntrega(datos);
        return solicitud;
    }

    private Viaje viajeDelivery(SituacionViaje situacion, EstadoEntrega estadoEntrega) {
        SolicitudViaje solicitud = solicitudEncomienda();
        solicitud.getDatosEntrega().setEstadoEntrega(estadoEntrega);
        Viaje viaje = new Viaje();
        viaje.setId(500L);
        viaje.setSolicitud(solicitud);
        viaje.setPasajero(pasajero);
        viaje.setConductor(conductor);
        viaje.setVehiculo(motoDelivery);
        viaje.setCategoriaServicio(delivery);
        viaje.setOrigen(solicitud.getOrigen());
        viaje.setDestino(solicitud.getDestino());
        viaje.setPrecioFinal(new BigDecimal("17.50"));
        viaje.setSituacionViaje(situacion);
        return viaje;
    }

    private Usuario usuario(Long id, String nombre) {
        Persona persona = new Persona();
        persona.setNombres(nombre);
        persona.setApellidos("Prueba");
        Usuario usuario = new Usuario();
        usuario.setId(id);
        usuario.setPersona(persona);
        return usuario;
    }

    private void autenticarConductor() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtUser(20L, "repartidor", "CONDUCTOR"), null));
    }

    private void autenticarPasajero() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtUser(10L, "pasajera", "PASAJERO"), null));
    }

    private Point punto(double longitud, double latitud) {
        return GEOMETRIA.createPoint(new Coordinate(longitud, latitud));
    }
}