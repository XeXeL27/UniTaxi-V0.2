package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
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
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryService;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.dto.EntregarPedidoRequest;
import com.taxiuap.backend.trip.dto.RecogerPaqueteRequest;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.trip.repository.DatosEntregaRepository;

/**
 * Recogida y entrega sin codigos ni fotos: en A se recibe el paquete (foto opcional) y en B se entrega
 * con el GPS cerca; solo si recibe otra persona se escribe su nombre completo, que tiene que ser el que
 * dio el cliente.
 */
@ExtendWith(MockitoExtension.class)
class EntregaSinCodigoTest {

    private static final GeometryFactory GEOMETRIA = new GeometryFactory(new PrecisionModel(), 4326);

    @Mock private ViajeService viajeService;
    @Mock private DatosEntregaRepository datosEntregaRepository;
    @Mock private CalculoPrecioDeliveryService calculoPrecioDeliveryService;
    @Mock private AlmacenamientoArchivos almacenamientoArchivos;

    private EntregaService entregaService;

    @BeforeEach
    void setUp() {
        entregaService = new EntregaService(viajeService, datosEntregaRepository,
                calculoPrecioDeliveryService, almacenamientoArchivos);
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtUser(20L, "repartidor", "CONDUCTOR"), null));
    }

    @AfterEach
    void limpiarSeguridad() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void elPaqueteSeRecogeSinCodigoNiFoto() {
        Viaje viaje = viaje(TipoEnvio.ENCOMIENDA, SituacionViaje.CONDUCTOR_LLEGO, EstadoEntrega.EN_CAMINO_RECOGIDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(datosEntregaRepository.avanzarSiEstadoPermitido(eq(1L), anyCollection(), eq(EstadoEntrega.EN_MANO)))
                .thenReturn(1);
        when(datosEntregaRepository.findBySolicitudId(90L))
                .thenReturn(Optional.of(viaje.getSolicitud().getDatosEntrega()));

        entregaService.recogerPaquete(500L, new RecogerPaqueteRequest(-11.02, -68.75), null);

        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        assertNull(datos.getFotoRecogidaUrl());
        assertTrue(datos.getFechaRecogida() != null);
        verify(viajeService).registrarPedidoEnMano(500L, null);
        verify(viajeService).avisarPasajero(eq(viaje), eq("PAQUETE_RECOGIDO"), anyString(), anyString());
        verify(almacenamientoArchivos, never()).guardarConSello(any(), any(), anyString(), anyString());
    }

    @Test
    void sinMarcarLaLlegadaNoSeRecoge() {
        Viaje viaje = viaje(TipoEnvio.ENCOMIENDA, SituacionViaje.CONDUCTOR_EN_CAMINO, EstadoEntrega.EN_CAMINO_RECOGIDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        assertThrows(NegocioException.class,
                () -> entregaService.recogerPaquete(500L, new RecogerPaqueteRequest(-11.02, -68.75), null));
        verify(datosEntregaRepository, never()).avanzarSiEstadoPermitido(anyLong(), anyCollection(), any());
    }

    @Test
    void elClienteRecibeSinDarNingunDato() {
        Viaje viaje = enManoPagado(TipoEnvio.ENCOMIENDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(datosEntregaRepository.avanzarSiEstadoPermitido(eq(1L), anyCollection(), eq(EstadoEntrega.ENTREGADO)))
                .thenReturn(1);
        when(datosEntregaRepository.findBySolicitudId(90L))
                .thenReturn(Optional.of(viaje.getSolicitud().getDatosEntrega()));

        entregaService.entregarPedido(500L, new EntregarPedidoRequest(null, -11.03, -68.74));

        verify(viajeService).finalizarDesdeEntrega(eq(500L), any());
        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        assertNull(datos.getFotoEntregaUrl());
        assertEquals("ANA PRUEBA", datos.getReceptorIdentificado());
    }

    @Test
    void otraPersonaRecibeConSuNombreCompleto() {
        Viaje viaje = paraOtraPersona(enManoPagado(TipoEnvio.COMPRA_Y_ENTREGA), "Juan Pérez");
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(datosEntregaRepository.avanzarSiEstadoPermitido(eq(1L), anyCollection(), eq(EstadoEntrega.ENTREGADO)))
                .thenReturn(1);
        when(datosEntregaRepository.findBySolicitudId(90L))
                .thenReturn(Optional.of(viaje.getSolicitud().getDatosEntrega()));

        entregaService.entregarPedido(500L, new EntregarPedidoRequest("JUAN CARLOS PEREZ", -11.03, -68.74));

        assertEquals("JUAN CARLOS PEREZ", viaje.getSolicitud().getDatosEntrega().getReceptorIdentificado());
        verify(viajeService).finalizarDesdeEntrega(eq(500L), any());
    }

    @Test
    void otraPersonaSinNombreOConOtroNombreNoRecibe() {
        Viaje viaje = paraOtraPersona(enManoPagado(TipoEnvio.ENCOMIENDA), "Juan Pérez");
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException sinNombre = assertThrows(NegocioException.class,
                () -> entregaService.entregarPedido(500L, new EntregarPedidoRequest(" ", -11.03, -68.74)));
        assertTrue(sinNombre.getMessage().contains("nombre completo"));
        NegocioException otro = assertThrows(NegocioException.class,
                () -> entregaService.entregarPedido(500L, new EntregarPedidoRequest("Juan Mamani", -11.03, -68.74)));
        assertTrue(otro.getMessage().contains("no coincide"));
        verify(datosEntregaRepository, never()).avanzarSiEstadoPermitido(anyLong(), anyCollection(), any());
    }

    @Test
    void sinPagoOLejosNoSeEntrega() {
        Viaje viaje = enManoPagado(TipoEnvio.ENCOMIENDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        assertThrows(NegocioException.class,
                () -> entregaService.entregarPedido(500L, new EntregarPedidoRequest(null, -11.10, -68.74)));
        viaje.getSolicitud().getDatosEntrega().setPagoConfirmado(false);
        assertThrows(NegocioException.class,
                () -> entregaService.entregarPedido(500L, new EntregarPedidoRequest(null, -11.03, -68.74)));
        verify(datosEntregaRepository, never()).avanzarSiEstadoPermitido(anyLong(), anyCollection(), any());
    }

    @Test
    void elDeliverySinCostoAceptadoNoSeEntrega() {
        Viaje viaje = enManoPagado(TipoEnvio.COMPRA_Y_ENTREGA);
        viaje.getSolicitud().getDatosEntrega().setCompraConfirmadaPorCliente(false);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        assertThrows(NegocioException.class,
                () -> entregaService.entregarPedido(500L, new EntregarPedidoRequest(null, -11.03, -68.74)));
    }

    @Test
    void elNombreSeComparaSinTildesNiMayusculas() {
        assertTrue(EntregaService.nombreCoincide("juan perez", "JUAN PÉREZ"));
        assertTrue(EntregaService.nombreCoincide("Juan Carlos Pérez Mamani", "Juan Perez"));
        assertTrue(EntregaService.nombreCoincide("MUÑOZ ANA", "Ana Muñoz"));
        assertFalse(EntregaService.nombreCoincide("Juan", "Juan Perez"));
        assertFalse(EntregaService.nombreCoincide("", "Juan Perez"));
    }

    private Viaje enManoPagado(TipoEnvio tipo) {
        Viaje viaje = viaje(tipo, SituacionViaje.EN_CURSO, EstadoEntrega.EN_MANO);
        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        datos.setPagoConfirmado(true);
        datos.setMontoPagoRecibido(new BigDecimal("17.50"));
        if (tipo == TipoEnvio.COMPRA_Y_ENTREGA) {
            datos.setCompraConfirmadaPorCliente(true);
        }
        return viaje;
    }

    private Viaje paraOtraPersona(Viaje viaje, String nombre) {
        viaje.getSolicitud().setParaOtraPersona(true);
        viaje.getSolicitud().setNombrePasajeroTercero(nombre);
        viaje.getSolicitud().getDatosEntrega().setNombreReceptor(nombre);
        return viaje;
    }

    private Viaje viaje(TipoEnvio tipo, SituacionViaje situacion, EstadoEntrega estado) {
        Persona persona = new Persona();
        persona.setNombres("Ana");
        persona.setApellidos("Prueba");
        Usuario usuarioPasajero = new Usuario();
        usuarioPasajero.setId(10L);
        usuarioPasajero.setPersona(persona);
        Pasajero pasajero = new Pasajero();
        pasajero.setId(30L);
        pasajero.setUsuario(usuarioPasajero);

        Persona personaRepartidor = new Persona();
        personaRepartidor.setNombres("Rene");
        personaRepartidor.setApellidos("Prueba");
        Usuario usuarioRepartidor = new Usuario();
        usuarioRepartidor.setId(20L);
        usuarioRepartidor.setPersona(personaRepartidor);
        Conductor conductor = new Conductor();
        conductor.setId(40L);
        conductor.setUsuario(usuarioRepartidor);

        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setId(90L);
        solicitud.setPasajero(pasajero);
        solicitud.setOrigen(punto(-68.75, -11.02));
        solicitud.setDestino(punto(-68.74, -11.03));

        DatosEntrega datos = new DatosEntrega();
        datos.setId(1L);
        datos.setSolicitud(solicitud);
        datos.setTipoEnvio(tipo);
        datos.setDescripcion("Documentos");
        datos.setAceptaPoliticaArticulos(true);
        datos.setEstadoEntrega(estado);
        solicitud.setDatosEntrega(datos);

        Viaje viaje = new Viaje();
        viaje.setId(500L);
        viaje.setSolicitud(solicitud);
        viaje.setPasajero(pasajero);
        viaje.setConductor(conductor);
        viaje.setOrigen(solicitud.getOrigen());
        viaje.setDestino(solicitud.getDestino());
        viaje.setPrecioFinal(new BigDecimal("17.50"));
        viaje.setSituacionViaje(situacion);
        return viaje;
    }

    private Point punto(double longitud, double latitud) {
        return GEOMETRIA.createPoint(new Coordinate(longitud, latitud));
    }
}
