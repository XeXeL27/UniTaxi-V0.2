package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

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
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.dto.OfertaViajeRequest;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.OfertaViaje;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.enums.SituacionOferta;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.trip.repository.OfertaViajeRepository;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;
import com.taxiuap.backend.vehicle.service.DocumentoConductorService;

@ExtendWith(MockitoExtension.class)
class OfertaViajeDeliveryAcceptanceTest {

    @Mock private OfertaViajeRepository ofertaRepository;
    @Mock private SolicitudViajeRepository solicitudRepository;
    @Mock private ConductorRepository conductorRepository;
    @Mock private PasajeroRepository pasajeroRepository;
    @Mock private VehiculoRepository vehiculoRepository;
    @Mock private DocumentoConductorService documentoService;
    @Mock private ViajeService viajeService;
    @Mock private ViajeEventPublisher publisher;

    private OfertaViajeService service;
    private Conductor conductor;
    private SolicitudViaje compra;
    private CategoriaServicio delivery;
    private Vehiculo motoDelivery;

    @BeforeEach
    void setUp() {
        Persona persona = new Persona();
        persona.setNombres("Repartidor");
        persona.setApellidos("Prueba");
        Usuario usuario = new Usuario();
        usuario.setId(10L);
        usuario.setPersona(persona);
        conductor = new Conductor();
        conductor.setId(20L);
        conductor.setUsuario(usuario);
        conductor.setLimiteAdelantoCompra(new BigDecimal("50.00"));

        TipoVehiculo tipoMoto = new TipoVehiculo();
        tipoMoto.setCodigo("MOTO");
        delivery = new CategoriaServicio();
        delivery.setId(7);
        delivery.setNombre("DELIVERY");
        delivery.setTipoVehiculo(tipoMoto);
        motoDelivery = new Vehiculo();
        motoDelivery.setEstadoVehiculo(EstadoRegistro.A);
        motoDelivery.setTipoVehiculo(tipoMoto);
        motoDelivery.setCategoriaServicio(delivery);
        motoDelivery.setPlaca("DEL-123");

        compra = new SolicitudViaje();
        compra.setId(30L);
        compra.setCategoriaServicio(delivery);
        compra.setSituacionSolicitud(SituacionSolicitud.PENDIENTE);
        DatosEntrega datos = new DatosEntrega();
        datos.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        datos.setCostoProductoEstimado(new BigDecimal("25.00"));
        datos.setDescripcion("Compra de prueba");
        compra.setDatosEntrega(datos);

        service = new OfertaViajeService(ofertaRepository, solicitudRepository, conductorRepository,
                pasajeroRepository, vehiculoRepository, documentoService, viajeService, publisher);
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtUser(10L, "repartidor", "CONDUCTOR"), null));
        lenient().when(conductorRepository.findByUsuarioId(10L)).thenReturn(Optional.of(conductor));
    }

    @AfterEach
    void limpiarSeguridad() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void aceptaSolicitudDeliveryConMotoCompatibleConLimiteSuficiente() {
        when(documentoService.puedeOperar(20L)).thenReturn(true);
        when(viajeService.conductorTieneViajeActivo(20L)).thenReturn(false);
        when(solicitudRepository.existsById(30L)).thenReturn(true);
        when(solicitudRepository.findById(30L)).thenReturn(Optional.of(compra));
        when(solicitudRepository.aceptarSiDisponible(30L)).thenAnswer(invocacion -> {
            compra.setSituacionSolicitud(SituacionSolicitud.ACEPTADA);
            return 1;
        });
        when(conductorRepository.findById(20L)).thenReturn(Optional.of(conductor));
        when(ofertaRepository.findBySolicitudIdAndSituacionOferta(any(), any())).thenReturn(List.of());
        when(vehiculoRepository.findByConductorId(20L)).thenReturn(List.of(motoDelivery));
        when(viajeService.crearDesdeOferta(any(), any())).thenAnswer(invocacion -> {
            com.taxiuap.backend.trip.entity.Viaje viaje = new com.taxiuap.backend.trip.entity.Viaje();
            viaje.setId(40L);
            return viaje;
        });

        service.aceptarDirecto(30L);

        assertEquals(SituacionSolicitud.ACEPTADA, compra.getSituacionSolicitud());
        verify(viajeService).crearDesdeOferta(any(), any());
    }

    @Test
    void rechazaSolicitudDeliveryCuandoSoloTieneVehiculosEstandar() {
        when(documentoService.puedeOperar(20L)).thenReturn(true);
        when(viajeService.conductorTieneViajeActivo(20L)).thenReturn(false);
        when(solicitudRepository.existsById(30L)).thenReturn(true);
        when(solicitudRepository.findById(30L)).thenReturn(Optional.of(compra));
        TipoVehiculo tipoMoto = new TipoVehiculo();
        tipoMoto.setCodigo("MOTO");
        CategoriaServicio categoriaMoto = new CategoriaServicio();
        categoriaMoto.setId(8);
        categoriaMoto.setNombre("MOTO");
        categoriaMoto.setTipoVehiculo(tipoMoto);
        Vehiculo estandar = new Vehiculo();
        estandar.setEstadoVehiculo(EstadoRegistro.A);
        estandar.setTipoVehiculo(tipoMoto);
        estandar.setCategoriaServicio(categoriaMoto);
        TipoVehiculo tipoSedan = new TipoVehiculo();
        tipoSedan.setCodigo("SEDAN");
        CategoriaServicio categoriaEstandar = new CategoriaServicio();
        categoriaEstandar.setId(9);
        categoriaEstandar.setNombre("ESTANDAR");
        categoriaEstandar.setTipoVehiculo(tipoSedan);
        Vehiculo sedanEstandar = new Vehiculo();
        sedanEstandar.setEstadoVehiculo(EstadoRegistro.A);
        sedanEstandar.setTipoVehiculo(tipoSedan);
        sedanEstandar.setCategoriaServicio(categoriaEstandar);
        when(vehiculoRepository.findByConductorId(20L)).thenReturn(List.of(sedanEstandar, estandar));

        assertThrows(NegocioException.class, () -> service.aceptarDirecto(30L));

        verify(solicitudRepository, never()).aceptarSiDisponible(30L);
        verify(viajeService, never()).crearDesdeOferta(any(), any());
    }

    @Test
    void rechazaSolicitudDeliveryAlConductorNoAprobado() {
        when(documentoService.puedeOperar(20L)).thenReturn(false);

        assertThrows(NegocioException.class, () -> service.aceptarDirecto(30L));

        verify(solicitudRepository, never()).aceptarSiDisponible(30L);
        verify(viajeService, never()).crearDesdeOferta(any(), any());
    }

    @Test
    void rechazaCompraQueSuperaElLimiteDeAdelantoActual() {
        conductor.setLimiteAdelantoCompra(new BigDecimal("24.99"));
        when(documentoService.puedeOperar(20L)).thenReturn(true);
        when(viajeService.conductorTieneViajeActivo(20L)).thenReturn(false);
        when(solicitudRepository.existsById(30L)).thenReturn(true);
        when(solicitudRepository.findById(30L)).thenReturn(Optional.of(compra));
        when(vehiculoRepository.findByConductorId(20L)).thenReturn(List.of(motoDelivery));

        assertThrows(NegocioException.class, () -> service.aceptarDirecto(30L));

        verify(solicitudRepository, never()).aceptarSiDisponible(30L);
        verify(viajeService, never()).crearDesdeOferta(any(), any());
    }

    @Test
    void respuestaDeOfertaDeliveryConservaElPrecioDeServicioDeLaSolicitud() {
        compra.getDatosEntrega().setTipoEnvio(TipoEnvio.ENCOMIENDA);
        compra.setPrecioSugerido(new BigDecimal("17.50"));
        TipoVehiculo tipoMotoEstandar = new TipoVehiculo();
        tipoMotoEstandar.setCodigo("MOTO");
        CategoriaServicio categoriaMotoEstandar = new CategoriaServicio();
        categoriaMotoEstandar.setId(8);
        categoriaMotoEstandar.setNombre("MOTO");
        categoriaMotoEstandar.setTipoVehiculo(tipoMotoEstandar);
        Vehiculo motoEstandar = new Vehiculo();
        motoEstandar.setEstadoVehiculo(EstadoRegistro.A);
        motoEstandar.setTipoVehiculo(tipoMotoEstandar);
        motoEstandar.setCategoriaServicio(categoriaMotoEstandar);
        motoEstandar.setPlaca("STD-123");
        when(documentoService.puedeOperar(20L)).thenReturn(true);
        when(solicitudRepository.findById(30L)).thenReturn(Optional.of(compra));
        when(vehiculoRepository.findByConductorId(20L)).thenReturn(List.of(motoEstandar, motoDelivery));
        when(ofertaRepository.save(any())).thenAnswer(invocacion -> invocacion.getArgument(0));

        var respuesta = service.ofertar(30L, new OfertaViajeRequest(new BigDecimal("99.00"), 5));

        assertEquals(new BigDecimal("17.50"), respuesta.precioOfertado());
        assertEquals("DEL-123", respuesta.placaVehiculo());
    }

    @Test
    void pasajeroNoPuedeAceptarOfertaDeRepartidorQueYaNoEstaAprobado() {
        Pasajero pasajero = new Pasajero();
        pasajero.setId(30L);
        Usuario usuarioPasajero = new Usuario();
        usuarioPasajero.setId(30L);
        pasajero.setUsuario(usuarioPasajero);
        compra.setPasajero(pasajero);
        OfertaViaje oferta = new OfertaViaje();
        oferta.setId(31L);
        oferta.setSolicitud(compra);
        oferta.setConductor(conductor);
        oferta.setSituacionOferta(SituacionOferta.PENDIENTE);

        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtUser(30L, "pasajero", "PASAJERO"), null));
        when(ofertaRepository.findById(31L)).thenReturn(Optional.of(oferta));
        when(pasajeroRepository.findByUsuarioId(30L)).thenReturn(Optional.of(pasajero));
        lenient().when(viajeService.conductorTieneViajeActivo(20L)).thenReturn(false);
        when(documentoService.puedeOperar(20L)).thenReturn(false);
        lenient().when(viajeService.crearDesdeOferta(any(), any())).thenAnswer(invocacion -> {
            com.taxiuap.backend.trip.entity.Viaje viaje = new com.taxiuap.backend.trip.entity.Viaje();
            viaje.setId(40L);
            return viaje;
        });
        lenient().when(solicitudRepository.aceptarSiDisponible(30L)).thenAnswer(invocacion -> {
            compra.setSituacionSolicitud(SituacionSolicitud.ACEPTADA);
            return 1;
        });
        lenient().when(solicitudRepository.findById(30L)).thenReturn(Optional.of(compra));
        lenient().when(ofertaRepository.findBySolicitudIdAndSituacionOferta(any(), any())).thenReturn(List.of());

        assertThrows(NegocioException.class, () -> service.aceptar(31L));

        verify(solicitudRepository, never()).aceptarSiDisponible(30L);
        verify(viajeService, never()).crearDesdeOferta(any(), any());
    }
}
