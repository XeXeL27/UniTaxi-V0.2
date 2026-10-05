package com.taxiuap.backend.trip.service;

import com.taxiuap.backend.trip.dto.SolicitudViajeResponse;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.locationtech.jts.geom.Point;
import org.mockito.InjectMocks;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.pricing.dto.CotizacionViaje;
import com.taxiuap.backend.pricing.dto.DesglosePrecioDelivery;
import com.taxiuap.backend.pricing.enums.MetodoPago;
import com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryService;
import com.taxiuap.backend.pricing.service.CalculoPrecioService;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.dto.DatosEntregaRequest;
import com.taxiuap.backend.trip.dto.SolicitudViajeRequest;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.trip.repository.DatosEntregaRepository;
import com.taxiuap.backend.trip.repository.OfertaViajeRepository;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;
import com.taxiuap.backend.vehicle.service.DocumentoConductorService;

@ExtendWith(MockitoExtension.class)
class SolicitudViajeDeliveryFlowTest {

    @Mock private SolicitudViajeRepository solicitudRepository;
    @Mock private OfertaViajeRepository ofertaRepository;
    @Mock private PasajeroRepository pasajeroRepository;
    @Mock private ConductorRepository conductorRepository;
    @Mock private CategoriaServicioRepository categoriaRepository;
    @Mock private VehiculoRepository vehiculoRepository;
    @Mock private DatosEntregaRepository datosRepository;
    @Mock private DocumentoConductorService documentoService;
    @Mock private ViajeEventPublisher publisher;
    @Mock private ViajeService viajeService;
    @Mock private CalculoPrecioService precioService;
    @Mock private CalculoPrecioDeliveryService precioDeliveryService;

    @InjectMocks private SolicitudViajeService service;
    private Pasajero pasajero;
    private CategoriaServicio delivery;

    @BeforeEach
    void setUp() {
        Persona persona = new Persona();
        persona.setId(20L);
        Usuario usuario = new Usuario();
        usuario.setId(10L);
        usuario.setPersona(persona);
        pasajero = new Pasajero();
        pasajero.setId(30L);
        pasajero.setUsuario(usuario);

        TipoVehiculo moto = new TipoVehiculo();
        moto.setId(1);
        moto.setCodigo("MOTO");
        delivery = new CategoriaServicio();
        delivery.setId(7);
        delivery.setNombre("DELIVERY");
        delivery.setTipoVehiculo(moto);

        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtUser(10L, "pasajero", "PASAJERO"), null));
        lenient().when(pasajeroRepository.findByUsuarioId(10L)).thenReturn(Optional.of(pasajero));
        lenient().when(solicitudRepository.existsByPasajeroIdAndSituacionSolicitudIn(any(), any())).thenReturn(false);
        lenient().when(viajeService.pasajeroTieneViajeActivo(30L)).thenReturn(false);
        // Taxi: precio por tramos de km (8 Bs, sin descuento de estudiante).
        lenient().when(precioService.cotizar(any(), any(), any())).thenReturn(new CotizacionViaje(
                new BigDecimal("3.00"), 5, true, new BigDecimal("8.00"), new BigDecimal("0.00"),
                new BigDecimal("8.00"), null));
        lenient().when(ofertaRepository.findBySolicitudIdAndSituacionOferta(any(), any())).thenReturn(List.of());
        lenient().when(solicitudRepository.save(any())).thenAnswer(invocation -> {
            SolicitudViaje solicitud = invocation.getArgument(0);
            solicitud.setId(100L);
            return solicitud;
        });
        lenient().when(datosRepository.save(any())).thenAnswer(invocation -> {
            DatosEntrega datos = invocation.getArgument(0);
            datos.setId(200L);
            return datos;
        });
    }

    @AfterEach
    void limpiarSeguridad() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void creaEncomiendaConPrecioYCodigosIndependientes() {
        when(categoriaRepository.findById(7)).thenReturn(Optional.of(delivery));
        lenient().when(precioDeliveryService.calcularEncomienda(any(Point.class), any(Point.class)))
                .thenReturn(new DesglosePrecioDelivery(new BigDecimal("17.50"), new BigDecimal("4.25"), 13, false));
        SolicitudViajeRequest request = request(new DatosEntregaRequest(TipoEnvio.ENCOMIENDA,
                "Documentos", BigDecimal.ZERO, "Ana", "70000000", "Luis", "71111111", null, true),
                new BigDecimal("99.00"));

        var respuesta = service.crear(request);

        assertEquals(new BigDecimal("17.50"), respuesta.precioSugerido());
        ArgumentCaptor<SolicitudViaje> solicitudGuardada = ArgumentCaptor.forClass(SolicitudViaje.class);
        verify(solicitudRepository).save(solicitudGuardada.capture());
        assertEquals(new BigDecimal("17.50"), solicitudGuardada.getValue().getPrecioSugerido());
        assertNotNull(respuesta.datosEntrega());
        assertNotNull(respuesta.datosEntrega().codigoRecogida());
        assertNotNull(respuesta.datosEntrega().codigoEntrega());
        assertTrue(!respuesta.datosEntrega().codigoRecogida().equals(respuesta.datosEntrega().codigoEntrega()));
        verify(precioDeliveryService).calcularEncomienda(any(Point.class), any(Point.class));
    }

    @Test
    void falloDeRutaImpideCrearLaSolicitudEncomienda() {
        when(categoriaRepository.findById(7)).thenReturn(Optional.of(delivery));
        doThrow(new IllegalStateException("OSRM no disponible"))
                .when(precioDeliveryService).calcularEncomienda(any(Point.class), any(Point.class));

        assertThrows(IllegalStateException.class, () -> service.crear(request(
                new DatosEntregaRequest(TipoEnvio.ENCOMIENDA, "Documentos", BigDecimal.ZERO,
                        "Ana", "70000000", "Luis", "71111111", null, true),
                new BigDecimal("99.00"))));

        verify(solicitudRepository, never()).save(any());
    }

    @Test
    void creaCompraConEstimadoPeroSinPrecioDefinitivo() {
        when(categoriaRepository.findById(7)).thenReturn(Optional.of(delivery));
        SolicitudViajeRequest request = request(new DatosEntregaRequest(TipoEnvio.COMPRA_Y_ENTREGA,
                "Medicamento", new BigDecimal("25.00"), null, null, null, null, null, null));

        var respuesta = service.crear(request);

        assertNull(respuesta.precioSugerido());
        assertEquals(new BigDecimal("25.00"), respuesta.datosEntrega().costoProductoEstimado());
        assertNull(respuesta.datosEntrega().codigoRecogida());
    }

    @Test
    void unaCompraSinAsignarNoMarcaElPrecioComoEstimado() {
        when(categoriaRepository.findById(7)).thenReturn(Optional.of(delivery));

        var respuesta = service.crear(request(new DatosEntregaRequest(TipoEnvio.COMPRA_Y_ENTREGA,
                "Medicamento", new BigDecimal("25.00"), null, null, null, null, null, null)));

        assertTrue(respuesta.toString().contains("precioEstimado=false"));
    }

    @Test
    void solicitudDeCompraMuestraElSnapshotEstimadoHastaRegistrarLaCompra() {
        SolicitudViaje compra = solicitudCompra(new BigDecimal("25.00"));
        compra.setPrecioSugerido(new BigDecimal("21.75"));
        compra.setSituacionSolicitud(com.taxiuap.backend.trip.enums.SituacionSolicitud.ACEPTADA);
        when(solicitudRepository.findById(90L)).thenReturn(Optional.of(compra));

        var antesDeComprar = service.obtenerPropia(90L);
        assertEquals(new BigDecimal("21.75"), antesDeComprar.precioSugerido());
        assertTrue(antesDeComprar.toString().contains("precioEstimado=true"));

        compra.getDatosEntrega().setCostoProductoReal(new BigDecimal("25.00"));
        compra.setPrecioSugerido(new BigDecimal("16.25"));
        var despuesDeComprar = service.obtenerPropia(90L);
        assertEquals(new BigDecimal("16.25"), despuesDeComprar.precioSugerido());
        assertFalse(despuesDeComprar.toString().contains("precioEstimado=true"));
    }

    @Test
    void noListaCompraSobreElLimiteDelRepartidor() {
        Conductor conductor = conductor(40L, new BigDecimal("20.00"));
        SolicitudViaje solicitud = solicitudCompra(new BigDecimal("25.00"));
        Vehiculo motoDelivery = vehiculo(delivery, delivery.getTipoVehiculo());
        when(conductorRepository.findByUsuarioId(10L)).thenReturn(Optional.of(conductor));
        when(documentoService.puedeOperar(40L)).thenReturn(true);
        when(solicitudRepository.findBySituacionSolicitud(any())).thenReturn(List.of(solicitud));
        when(ofertaRepository.existsBySolicitudIdAndConductorIdAndSituacionOferta(any(), any(), any())).thenReturn(false);
        when(vehiculoRepository.findByConductorId(40L)).thenReturn(List.of(motoDelivery));

        assertTrue(service.listarDisponiblesParaConductor().isEmpty());
    }

    @Test
    void elRepartidorNoVeViajesDeTaxi() {
        Conductor repartidor = conductor(40L, new BigDecimal("100.00"));
        when(conductorRepository.findByUsuarioId(10L)).thenReturn(Optional.of(repartidor));
        when(documentoService.puedeOperar(40L)).thenReturn(true);
        when(solicitudRepository.findBySituacionSolicitud(any())).thenReturn(List.of(solicitudTaxi(91L)));
        when(ofertaRepository.existsBySolicitudIdAndConductorIdAndSituacionOferta(any(), any(), any())).thenReturn(false);
        when(vehiculoRepository.findByConductorId(40L)).thenReturn(List.of(vehiculo(delivery, delivery.getTipoVehiculo())));

        assertTrue(service.listarDisponiblesParaConductor().isEmpty());
    }

    @Test
    void elTaxistaVeLosViajesDeTaxiPeroNoLasEntregas() {
        Conductor taxista = conductor(41L, BigDecimal.ZERO);
        CategoriaServicio motoTaxi = new CategoriaServicio();
        motoTaxi.setId(3);
        motoTaxi.setNombre("MOTO");
        motoTaxi.setTipoVehiculo(delivery.getTipoVehiculo());
        SolicitudViaje entrega = solicitudCompra(new BigDecimal("5.00"));
        when(conductorRepository.findByUsuarioId(10L)).thenReturn(Optional.of(taxista));
        when(documentoService.puedeOperar(41L)).thenReturn(true);
        when(solicitudRepository.findBySituacionSolicitud(SituacionSolicitud.PENDIENTE))
                .thenReturn(List.of(solicitudTaxi(92L), entrega));
        when(solicitudRepository.findBySituacionSolicitud(SituacionSolicitud.CON_OFERTAS)).thenReturn(List.of());
        when(ofertaRepository.existsBySolicitudIdAndConductorIdAndSituacionOferta(any(), any(), any())).thenReturn(false);
        when(vehiculoRepository.findByConductorId(41L)).thenReturn(List.of(vehiculo(motoTaxi, delivery.getTipoVehiculo())));

        List<SolicitudViajeResponse> vistas = service.listarDisponiblesParaConductor();
        assertEquals(1, vistas.size());
        assertEquals(92L, vistas.getFirst().idSolicitud());
    }

    private SolicitudViaje solicitudTaxi(Long id) {
        CategoriaServicio motoTaxi = new CategoriaServicio();
        motoTaxi.setId(3);
        motoTaxi.setNombre("MOTO");
        motoTaxi.setTipoVehiculo(delivery.getTipoVehiculo());
        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setId(id);
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(motoTaxi);
        solicitud.setPrecioSugerido(new BigDecimal("8.00"));
        return solicitud;
    }

    private SolicitudViajeRequest request(DatosEntregaRequest datos) {
        return request(datos, null);
    }

    private SolicitudViajeRequest request(DatosEntregaRequest datos, BigDecimal precioCliente) {
        return new SolicitudViajeRequest(7, "POINT (-68.75 -11.02)", "POINT (-68.74 -11.03)",
                "A", "B", null, precioCliente, MetodoPago.EFECTIVO, datos);
    }

    private SolicitudViaje solicitudCompra(BigDecimal costo) {
        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setId(90L);
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(delivery);
        DatosEntrega datos = new DatosEntrega();
        datos.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        datos.setDescripcion("Compra");
        datos.setCostoProductoEstimado(costo);
        solicitud.setDatosEntrega(datos);
        return solicitud;
    }

    private Conductor conductor(Long id, BigDecimal limite) {
        Conductor conductor = new Conductor();
        conductor.setId(id);
        conductor.setLimiteAdelantoCompra(limite);
        Usuario usuario = new Usuario();
        Persona persona = new Persona();
        persona.setId(99L);
        usuario.setPersona(persona);
        conductor.setUsuario(usuario);
        return conductor;
    }

    private Vehiculo vehiculo(CategoriaServicio categoria, TipoVehiculo tipo) {
        Vehiculo vehiculo = new Vehiculo();
        vehiculo.setEstadoVehiculo(EstadoRegistro.A);
        vehiculo.setCategoriaServicio(categoria);
        vehiculo.setTipoVehiculo(tipo);
        return vehiculo;
    }
}
