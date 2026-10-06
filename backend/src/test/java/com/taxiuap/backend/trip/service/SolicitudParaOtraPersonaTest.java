package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
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
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.pricing.dto.CotizacionViaje;
import com.taxiuap.backend.pricing.enums.MetodoPago;
import com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryService;
import com.taxiuap.backend.pricing.service.CalculoPrecioService;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.dto.SolicitudViajeRequest;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.repository.DatosEntregaRepository;
import com.taxiuap.backend.trip.repository.OfertaViajeRepository;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;
import com.taxiuap.backend.vehicle.service.DocumentoConductorService;

/**
 * Taxi pedido para otra persona: quien viaja no tiene cuenta, su nombre y celular son obligatorios, el
 * descuento de estudiante de quien pide no se aplica y, si paga quien pide, el pago es por QR.
 */
@ExtendWith(MockitoExtension.class)
class SolicitudParaOtraPersonaTest {

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

    @BeforeEach
    void setUp() {
        Persona persona = new Persona();
        persona.setId(20L);
        Usuario usuario = new Usuario();
        usuario.setId(10L);
        usuario.setPersona(persona);
        Pasajero pasajero = new Pasajero();
        pasajero.setId(30L);
        pasajero.setUsuario(usuario);

        TipoVehiculo moto = new TipoVehiculo();
        moto.setId(1);
        moto.setCodigo("MOTO");
        CategoriaServicio estandar = new CategoriaServicio();
        estandar.setId(1);
        estandar.setNombre("ESTANDAR");
        estandar.setTipoVehiculo(moto);

        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtUser(10L, "pasajero", "PASAJERO"), null));
        lenient().when(pasajeroRepository.findByUsuarioId(10L)).thenReturn(Optional.of(pasajero));
        lenient().when(solicitudRepository.existsByPasajeroIdAndSituacionSolicitudIn(any(), any())).thenReturn(false);
        lenient().when(viajeService.pasajeroTieneViajeActivo(30L)).thenReturn(false);
        lenient().when(categoriaRepository.findById(1)).thenReturn(Optional.of(estandar));
        // Quien pide es estudiante: 8 Bs con 2 Bs de descuento.
        lenient().when(precioService.cotizar(any(), any(), any())).thenReturn(new CotizacionViaje(
                new BigDecimal("3.00"), 5, true, new BigDecimal("8.00"), new BigDecimal("2.00"),
                new BigDecimal("6.00"), null));
        lenient().when(ofertaRepository.findBySolicitudIdAndSituacionOferta(any(), any())).thenReturn(List.of());
        lenient().when(solicitudRepository.save(any())).thenAnswer(invocation -> {
            SolicitudViaje solicitud = invocation.getArgument(0);
            solicitud.setId(100L);
            return solicitud;
        });
    }

    @AfterEach
    void limpiarSeguridad() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void paraOtraPersonaGuardaQuienViajaYNoAplicaElDescuento() {
        var respuesta = service.crear(request("juan  perez", "71234567", false, MetodoPago.EFECTIVO));

        SolicitudViaje guardada = guardada();
        assertTrue(guardada.esParaOtraPersona());
        assertEquals("JUAN PEREZ", guardada.getNombrePasajeroTercero());
        assertEquals("71234567", guardada.getTelefonoPasajeroTercero());
        assertEquals(0, guardada.getDescuentoEstudiante().signum());
        assertEquals(MetodoPago.EFECTIVO, guardada.getMetodoPago());
        // Precio normal: sin el descuento de estudiante de quien pide.
        assertEquals(new BigDecimal("8.00"), respuesta.precioSugerido());
        // A quien pidio se le devuelve el celular de quien viaja.
        assertEquals("71234567", respuesta.telefonoPasajeroTercero());
        // A los conductores no les llega el celular hasta que aceptan el viaje.
        assertNull(respuesta.sinNombreDestino().telefonoPasajeroTercero());
    }

    @Test
    void siPagaQuienPideElPagoEsPorQr() {
        service.crear(request("Juan Perez", "71234567", true, MetodoPago.EFECTIVO));

        SolicitudViaje guardada = guardada();
        assertTrue(guardada.getPagaSolicitante());
        assertEquals(MetodoPago.QR, guardada.getMetodoPago());
    }

    @Test
    void sinCelularValidoNoSePide() {
        NegocioException error = assertThrows(NegocioException.class,
                () -> service.crear(request("Juan Perez", "123", false, MetodoPago.EFECTIVO)));

        assertTrue(error.getMessage().contains("celular"));
        verify(solicitudRepository, never()).save(any());
    }

    @Test
    void sinNombreNoSePide() {
        assertThrows(NegocioException.class,
                () -> service.crear(request("  ", "71234567", false, MetodoPago.EFECTIVO)));

        verify(solicitudRepository, never()).save(any());
    }

    @Test
    void elViajePropioConservaElDescuento() {
        service.crear(new SolicitudViajeRequest(1, "POINT (-68.75 -11.02)", "POINT (-68.74 -11.03)",
                "A", "B", null, null, MetodoPago.EFECTIVO, null));

        SolicitudViaje guardada = guardada();
        assertEquals(new BigDecimal("2.00"), guardada.getDescuentoEstudiante());
        assertEquals(false, guardada.esParaOtraPersona());
    }

    @Test
    void laCotizacionParaOtraPersonaNoTieneDescuento() {
        var cotizacion = service.cotizar(-11.02, -68.75, -11.03, -68.74, true);

        assertEquals(new BigDecimal("8.00"), cotizacion.precio());
        assertEquals(0, cotizacion.descuentoEstudiante().signum());
    }

    private SolicitudViaje guardada() {
        ArgumentCaptor<SolicitudViaje> captor = ArgumentCaptor.forClass(SolicitudViaje.class);
        verify(solicitudRepository).save(captor.capture());
        return captor.getValue();
    }

    private SolicitudViajeRequest request(String nombre, String telefono, boolean pagaSolicitante, MetodoPago metodo) {
        return new SolicitudViajeRequest(1, "POINT (-68.75 -11.02)", "POINT (-68.74 -11.03)", "A", "B", null, null,
                metodo, null, true, nombre, telefono, pagaSolicitante);
    }
}
