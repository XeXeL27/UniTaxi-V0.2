package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.spy;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
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
import com.taxiuap.backend.institution.service.EstudianteService;
import com.taxiuap.backend.institution.service.MatriculaEstudianteService;
import com.taxiuap.backend.location.entity.UbicacionConductor;
import com.taxiuap.backend.location.entity.Zona;
import com.taxiuap.backend.location.repository.UbicacionConductorRepository;
import com.taxiuap.backend.location.repository.ZonaRepository;
import com.taxiuap.backend.pricing.dto.CalculoPrecio;
import com.taxiuap.backend.pricing.dto.DesglosePrecioDelivery;
import com.taxiuap.backend.pricing.entity.Tarifa;
import com.taxiuap.backend.pricing.repository.BilleteraConductorRepository;
import com.taxiuap.backend.pricing.repository.ComisionRepository;
import com.taxiuap.backend.pricing.repository.PagoRepository;
import com.taxiuap.backend.pricing.repository.ReglaDescuentoEstudiantilRepository;
import com.taxiuap.backend.pricing.repository.TarifaRepository;
import com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryService;
import com.taxiuap.backend.pricing.service.CalculoPrecioService;
import com.taxiuap.backend.pricing.service.QrPagoConductorService;
import com.taxiuap.backend.rating.repository.CalificacionRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.OfertaViaje;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.dto.FinalizarViajeRequest;
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

@ExtendWith(MockitoExtension.class)
class ViajeDeliveryPricingTest {

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
    @Mock private ZonaRepository zonaRepository;
    @Mock private ReglaDescuentoEstudiantilRepository reglaDescuentoRepository;
    @Mock private EstudianteService estudianteService;
    @Mock private MatriculaEstudianteService matriculaEstudianteService;

    private CalculoPrecioService calculoPrecioService;
    private ViajeService viajeService;

    private CategoriaServicio delivery;
    private Tarifa tarifa;
    private Pasajero pasajero;
    private Conductor conductor;
    private Vehiculo motoEstandar;
    private Vehiculo motoDelivery;
    private Point destino;

    @BeforeEach
    void setUp() {
        TipoVehiculo tipoMoto = new TipoVehiculo();
        tipoMoto.setCodigo("MOTO");
        delivery = new CategoriaServicio();
        delivery.setId(7);
        delivery.setNombre("DELIVERY");
        delivery.setTipoVehiculo(tipoMoto);

        CategoriaServicio categoriaMoto = new CategoriaServicio();
        categoriaMoto.setId(8);
        categoriaMoto.setNombre("MOTO");
        categoriaMoto.setTipoVehiculo(tipoMoto);

        tarifa = new Tarifa();
        tarifa.setCategoriaServicio(delivery);
        tarifa.setZona(new Zona());
        tarifa.setTarifaBase(new BigDecimal("3.00"));
        tarifa.setPrecioKm(new BigDecimal("1.00"));
        tarifa.setPrecioMinuto(new BigDecimal("1.00"));
        tarifa.setTarifaMinima(new BigDecimal("3.00"));
        tarifa.setVigenteDesde(LocalDate.of(2020, 1, 1));
        tarifa.setEstadoTarifa(EstadoRegistro.A);
        lenient().when(zonaRepository.findAll()).thenReturn(List.of());
        lenient().when(tarifaRepository.findByCategoriaServicioId(7)).thenReturn(List.of(tarifa));
        calculoPrecioService = spy(new CalculoPrecioService(tarifaRepository, zonaRepository,
                reglaDescuentoRepository, estudianteService, matriculaEstudianteService, viajeRepository));

        pasajero = new Pasajero();
        pasajero.setId(30L);
        pasajero.setUsuario(usuario(10L, "Pasajera"));
        conductor = new Conductor();
        conductor.setId(40L);
        conductor.setUsuario(usuario(20L, "Repartidor"));

        motoEstandar = vehiculo(1L, categoriaMoto, tipoMoto);
        motoDelivery = vehiculo(2L, delivery, tipoMoto);
        destino = punto(-68.74, -11.03);

        lenient().when(viajeRepository.save(any(Viaje.class))).thenAnswer(invocacion -> {
            Viaje viaje = invocacion.getArgument(0);
            viaje.setId(500L);
            return viaje;
        });
        viajeService = new ViajeService(viajeRepository, pasajeroRepository, conductorRepository, vehiculoRepository,
                pagoRepository, comisionRepository, billeteraConductorRepository, calculoPrecioService,
                calculoPrecioDeliveryService,
                historialViajeService, mensajeriaTemplate, calificacionRepository, qrPagoConductorService,
                solicitudViajeRepository, datosEntregaRepository, ofertaViajeRepository,
                ubicacionConductorRepository, notificacionPushService);
    }

    @AfterEach
    void limpiarSeguridad() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void encomiendaUsaElPrecioSnapshotYLaMotoDeliveryAunqueHayaUnaMotoEstandarPrimero() {
        SolicitudViaje solicitud = solicitud(TipoEnvio.ENCOMIENDA, new BigDecimal("17.50"));
        OfertaViaje oferta = oferta(solicitud);
        Tarifa tecnica = new Tarifa();
        tecnica.setCategoriaServicio(delivery);
        tecnica.setTarifaBase(BigDecimal.ZERO);
        tecnica.setPrecioKm(BigDecimal.ZERO);
        tecnica.setPrecioMinuto(BigDecimal.ZERO);
        tecnica.setTarifaMinima(BigDecimal.ZERO);
        tecnica.setVigenteDesde(LocalDate.of(2020, 1, 1));
        tecnica.setEstadoTarifa(EstadoRegistro.A);
        when(tarifaRepository.findByCategoriaServicioId(7)).thenReturn(List.of(tecnica, tarifa));
        when(vehiculoRepository.findByConductorId(40L)).thenReturn(List.of(motoEstandar, motoDelivery));
        lenient().doReturn(new CalculoPrecio(new BigDecimal("5.00"), BigDecimal.ZERO, new BigDecimal("5.00"),
                tarifa, null, null, new BigDecimal("1.00"), 4))
                .when(calculoPrecioService).calcular(solicitud, oferta, pasajero);

        Viaje viaje = viajeService.crearDesdeOferta(solicitud, oferta);

        assertEquals(motoDelivery, viaje.getVehiculo());
        assertEquals(tarifa, viaje.getTarifa());
        assertEquals(new BigDecimal("17.50"), viaje.getPrecioFinal());
        assertEquals(new BigDecimal("17.50"), viaje.getPrecioOriginal());
        assertEquals(new BigDecimal("0.00"), viaje.getMontoDescuento());
        verify(calculoPrecioService, never()).calcular(solicitud, oferta, pasajero);
    }

    @Test
    void creaTarifaTecnicaSinZonaAlAceptarDeliveryCuandoNoHayTarifaVigente() {
        SolicitudViaje solicitud = solicitud(TipoEnvio.ENCOMIENDA, new BigDecimal("17.50"));
        OfertaViaje oferta = oferta(solicitud);
        List<Tarifa> referencias = new ArrayList<>();
        when(vehiculoRepository.findByConductorId(40L)).thenReturn(List.of(motoDelivery));
        when(tarifaRepository.findByCategoriaServicioId(7))
                .thenAnswer(invocacion -> new ArrayList<>(referencias));
        when(tarifaRepository.save(any(Tarifa.class))).thenAnswer(invocacion -> {
            Tarifa referencia = invocacion.getArgument(0);
            referencias.add(referencia);
            return referencia;
        });

        Viaje viaje = assertDoesNotThrow(() -> viajeService.crearDesdeOferta(solicitud, oferta));
        Tarifa tarifaReutilizada = calculoPrecioService.tarifaVigente(solicitud);

        assertNotNull(viaje.getTarifa());
        assertSame(viaje.getTarifa(), tarifaReutilizada);
        verify(tarifaRepository, times(1)).save(any(Tarifa.class));
        assertNull(viaje.getTarifa().getZona());
        assertEquals(new BigDecimal("4.00"), viaje.getTarifa().getTarifaBase());
        assertEquals(new BigDecimal("1.80"), viaje.getTarifa().getPrecioKm());
        assertEquals(new BigDecimal("0.20"), viaje.getTarifa().getPrecioMinuto());
    }

    @Test
    void compraCalculaGpsADestinoPersisteElEstimadoYLoMarcaEnLaRespuestaDelViaje() {
        SolicitudViaje solicitud = solicitud(TipoEnvio.COMPRA_Y_ENTREGA, null);
        OfertaViaje oferta = oferta(solicitud);
        Point gpsActual = punto(-68.77, -11.02);
        UbicacionConductor ubicacion = new UbicacionConductor();
        ubicacion.setUbicacion(gpsActual);
        when(vehiculoRepository.findByConductorId(40L)).thenReturn(List.of(motoDelivery));
        when(ubicacionConductorRepository.findByConductorId(40L)).thenReturn(Optional.of(ubicacion));
        when(calculoPrecioDeliveryService.estimarCompra(gpsActual, destino))
                .thenReturn(new DesglosePrecioDelivery(new BigDecimal("21.25"), new BigDecimal("3.20"), 12, true));
        lenient().doReturn(new CalculoPrecio(new BigDecimal("5.00"), BigDecimal.ZERO, new BigDecimal("5.00"),
                tarifa, null, null, new BigDecimal("1.00"), 4))
                .when(calculoPrecioService).calcular(solicitud, oferta, pasajero);

        Viaje viaje = viajeService.crearDesdeOferta(solicitud, oferta);

        assertEquals(new BigDecimal("21.25"), solicitud.getPrecioSugerido());
        assertEquals(new BigDecimal("21.25"), viaje.getPrecioFinal());
        assertEquals(new BigDecimal("21.25"), viaje.getPrecioOriginal());
        assertEquals(new BigDecimal("3.20"), viaje.getDistanciaKm());
        assertEquals(12, viaje.getDuracionMin());
        assertTrue(viajeService.aRespuesta(viaje).toString().contains("precioEstimado=true"));
        verify(calculoPrecioDeliveryService).estimarCompra(gpsActual, destino);
        verify(calculoPrecioService, never()).calcular(solicitud, oferta, pasajero);

        var respuesta = viajeService.aRespuesta(viaje);
        assertEquals(new BigDecimal("21.25"), respuesta.precioFinal());
        assertTrue(respuesta.toString().contains("precioEstimado=true"));
        assertNull(respuesta.datosEntrega().codigoRecogida());
        assertNull(respuesta.datosEntrega().codigoEntrega());

        solicitud.getDatosEntrega().setCostoProductoReal(new BigDecimal("25.00"));
        solicitud.setPrecioSugerido(new BigDecimal("16.25"));
        viaje.setPrecioFinal(new BigDecimal("16.25"));
        assertFalse(viajeService.aRespuesta(viaje).toString().contains("precioEstimado=true"));
    }

    @Test
    void compraNoFijaPrecioSiOsrmFallaAlEstimar() {
        SolicitudViaje solicitud = solicitud(TipoEnvio.COMPRA_Y_ENTREGA, null);
        OfertaViaje oferta = oferta(solicitud);
        Point gpsActual = punto(-68.77, -11.02);
        UbicacionConductor ubicacion = new UbicacionConductor();
        ubicacion.setUbicacion(gpsActual);
        when(vehiculoRepository.findByConductorId(40L)).thenReturn(List.of(motoDelivery));
        when(ubicacionConductorRepository.findByConductorId(40L)).thenReturn(Optional.of(ubicacion));
        when(calculoPrecioDeliveryService.estimarCompra(gpsActual, destino))
                .thenThrow(new NegocioException("OSRM no disponible"));

        assertThrows(NegocioException.class, () -> viajeService.crearDesdeOferta(solicitud, oferta));

        assertNull(solicitud.getPrecioSugerido());
        verify(viajeRepository, never()).save(any(Viaje.class));
    }

    @Test
    void viajeEstandarConservaLaSeleccionDelPrimerVehiculoActivo() {
        CategoriaServicio estandar = new CategoriaServicio();
        estandar.setId(9);
        estandar.setNombre("ESTANDAR");
        TipoVehiculo sedan = new TipoVehiculo();
        sedan.setCodigo("SEDAN");
        estandar.setTipoVehiculo(sedan);
        Vehiculo primerActivo = vehiculo(3L, estandar, sedan);
        SolicitudViaje solicitud = solicitud(estandar, new BigDecimal("8.00"));
        OfertaViaje oferta = oferta(solicitud);
        when(vehiculoRepository.findByConductorId(40L)).thenReturn(List.of(primerActivo, motoDelivery));
        doReturn(new CalculoPrecio(new BigDecimal("8.00"), BigDecimal.ZERO, new BigDecimal("8.00"),
                tarifa, null, null, new BigDecimal("1.00"), 4))
                .when(calculoPrecioService).calcular(solicitud, oferta, pasajero);

        Viaje viaje = viajeService.crearDesdeOferta(solicitud, oferta);

        assertEquals(primerActivo, viaje.getVehiculo());
        assertEquals(SituacionViaje.CONFIRMADO, viaje.getSituacionViaje());
    }

    @Test
    void finalizacionDeliveryCobraSoloElServicioYUsaComisionDeliveryCeroPorDefecto() {
        SolicitudViaje solicitud = solicitud(TipoEnvio.COMPRA_Y_ENTREGA, new BigDecimal("21.25"));
        solicitud.getDatosEntrega().setCostoProductoReal(new BigDecimal("25.00"));
        Viaje viaje = new Viaje();
        viaje.setId(500L);
        viaje.setSolicitud(solicitud);
        viaje.setPasajero(pasajero);
        viaje.setConductor(conductor);
        viaje.setVehiculo(motoDelivery);
        viaje.setCategoriaServicio(delivery);
        viaje.setOrigen(solicitud.getOrigen());
        viaje.setDestino(solicitud.getDestino());
        viaje.setPrecioFinal(new BigDecimal("21.25"));
        viaje.setPrecioOriginal(new BigDecimal("21.25"));
        viaje.setMontoDescuento(new BigDecimal("0.00"));
        viaje.setSituacionViaje(SituacionViaje.EN_CURSO);
        when(conductorRepository.findByUsuarioId(20L)).thenReturn(Optional.of(conductor));
        when(viajeRepository.findById(500L)).thenReturn(Optional.of(viaje));
        when(billeteraConductorRepository.findByConductorId(40L)).thenReturn(Optional.of(billetera()));
        org.springframework.test.util.ReflectionTestUtils.setField(viajeService, "porcentajeComision",
                new BigDecimal("15.00"));
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtUser(20L, "repartidor", "CONDUCTOR"), null));

        // El viaje DELIVERY no se cierra con finalizar (esa via esta reservada al taxi): se cierra
        // desde la entrega, que es la que exige el pago confirmado antes de completar.
        viajeService.finalizarDesdeEntrega(500L, new FinalizarViajeRequest(null));

        ArgumentCaptor<com.taxiuap.backend.pricing.entity.Pago> pago =
                ArgumentCaptor.forClass(com.taxiuap.backend.pricing.entity.Pago.class);
        verify(pagoRepository).save(pago.capture());
        assertEquals(new BigDecimal("21.25"), pago.getValue().getMonto());
        ArgumentCaptor<com.taxiuap.backend.pricing.entity.Comision> comision =
                ArgumentCaptor.forClass(com.taxiuap.backend.pricing.entity.Comision.class);
        verify(comisionRepository).save(comision.capture());
        assertEquals(new BigDecimal("0"), comision.getValue().getPorcentaje());
        assertEquals(new BigDecimal("0.00"), comision.getValue().getMonto());
    }

    private SolicitudViaje solicitud(TipoEnvio tipo, BigDecimal precio) {
        SolicitudViaje solicitud = solicitud(delivery, precio);
        DatosEntrega datos = new DatosEntrega();
        datos.setSolicitud(solicitud);
        datos.setTipoEnvio(tipo);
        datos.setDescripcion("Paquete de prueba");
        datos.setCostoProductoEstimado(tipo == TipoEnvio.COMPRA_Y_ENTREGA ? new BigDecimal("25.00") : BigDecimal.ZERO);
        datos.setEstadoEntrega(com.taxiuap.backend.trip.enums.EstadoEntrega.PENDIENTE_RECOGIDA);
        solicitud.setDatosEntrega(datos);
        return solicitud;
    }

    private SolicitudViaje solicitud(CategoriaServicio categoria, BigDecimal precio) {
        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setId(90L);
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(categoria);
        solicitud.setOrigen(punto(-68.75, -11.02));
        solicitud.setDestino(destino);
        solicitud.setPrecioSugerido(precio);
        return solicitud;
    }

    private OfertaViaje oferta(SolicitudViaje solicitud) {
        OfertaViaje oferta = new OfertaViaje();
        oferta.setSolicitud(solicitud);
        oferta.setConductor(conductor);
        return oferta;
    }

    private Vehiculo vehiculo(Long id, CategoriaServicio categoria, TipoVehiculo tipo) {
        Vehiculo vehiculo = new Vehiculo();
        vehiculo.setId(id);
        vehiculo.setEstadoVehiculo(EstadoRegistro.A);
        vehiculo.setCategoriaServicio(categoria);
        vehiculo.setTipoVehiculo(tipo);
        return vehiculo;
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

    private com.taxiuap.backend.pricing.entity.BilleteraConductor billetera() {
        var billetera = new com.taxiuap.backend.pricing.entity.BilleteraConductor();
        billetera.setSaldo(BigDecimal.ZERO);
        billetera.setDeudaComision(BigDecimal.ZERO);
        return billetera;
    }

    private Point punto(double longitud, double latitud) {
        return GEOMETRIA.createPoint(new org.locationtech.jts.geom.Coordinate(longitud, latitud));
    }
}
