package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.lenient;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
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
import com.taxiuap.backend.pricing.enums.MetodoPago;
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

    private SolicitudViajeService service;
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

        service = new SolicitudViajeService(solicitudRepository, ofertaRepository, pasajeroRepository,
                conductorRepository, categoriaRepository, vehiculoRepository, datosRepository,
                documentoService, publisher, viajeService, precioService);
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtUser(10L, "pasajero", "PASAJERO"), null));
        lenient().when(pasajeroRepository.findByUsuarioId(10L)).thenReturn(Optional.of(pasajero));
        lenient().when(solicitudRepository.existsByPasajeroIdAndSituacionSolicitudIn(any(), any())).thenReturn(false);
        lenient().when(viajeService.pasajeroTieneViajeActivo(30L)).thenReturn(false);
        lenient().when(precioService.precioFijo()).thenReturn(new BigDecimal("8.00"));
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
        SolicitudViajeRequest request = request(new DatosEntregaRequest(TipoEnvio.ENCOMIENDA,
                "Documentos", BigDecimal.ZERO, "Ana", "70000000", "Luis", "71111111", null, true));

        var respuesta = service.crear(request);

        assertEquals(new BigDecimal("8.00"), respuesta.precioSugerido());
        assertNotNull(respuesta.datosEntrega());
        assertNotNull(respuesta.datosEntrega().codigoRecogida());
        assertNotNull(respuesta.datosEntrega().codigoEntrega());
        assertTrue(!respuesta.datosEntrega().codigoRecogida().equals(respuesta.datosEntrega().codigoEntrega()));
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

    private SolicitudViajeRequest request(DatosEntregaRequest datos) {
        return new SolicitudViajeRequest(7, "POINT (-68.75 -11.02)", "POINT (-68.74 -11.03)",
                "A", "B", null, null, MetodoPago.EFECTIVO, datos);
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
