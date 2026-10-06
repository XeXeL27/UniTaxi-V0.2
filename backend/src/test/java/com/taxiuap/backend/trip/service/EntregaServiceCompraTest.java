package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.util.Optional;

import javax.imageio.ImageIO;

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
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.pricing.dto.DesglosePrecioDelivery;
import com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryService;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.dto.IdentificarReceptorRequest;
import com.taxiuap.backend.trip.dto.ProponerCompraRequest;
import com.taxiuap.backend.trip.dto.RegistrarCompraRequest;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.trip.repository.DatosEntregaRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;

/**
 * COMPRA_Y_ENTREGA: el repartidor propone el comercio, el cliente lo confirma y solo entonces puede
 * comprar. El monto real nunca supera el confirmado sin una confirmacion nueva, y el precio del
 * servicio se recalcula desde el comercio real hasta el destino: el trayecto hasta el comercio no se
 * cobra y el producto nunca entra al precio de la plataforma.
 */
@ExtendWith(MockitoExtension.class)
class EntregaServiceCompraTest {

    private static final GeometryFactory GEOMETRIA = new GeometryFactory(new PrecisionModel(), 4326);
    private static final String WKT_COMERCIO = "POINT(-68.745 -11.025)";

    @Mock private ViajeService viajeService;
    @Mock private DatosEntregaRepository datosEntregaRepository;
    @Mock private CalculoPrecioDeliveryService calculoPrecioDeliveryService;
    @Mock private AlmacenamientoArchivos almacenamientoArchivos;

    private EntregaService entregaService;
    private Conductor conductor;

    @BeforeEach
    void setUp() {
        entregaService = new EntregaService(viajeService, datosEntregaRepository,
                calculoPrecioDeliveryService, almacenamientoArchivos);
        conductor = new Conductor();
        conductor.setId(40L);
        conductor.setUsuario(usuario(20L, "Repartidor", "999111"));
        conductor.setLimiteAdelantoCompra(new BigDecimal("100.00"));
    }

    @AfterEach
    void limpiarSeguridad() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void laPropuestaQuedaPendienteDeConfirmacionDelCliente() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_CAMINO_RECOGIDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(viajeService.obtener(500L)).thenReturn(null);
        when(calculoPrecioDeliveryService.puedeAdelantar(any(), any())).thenReturn(true);

        entregaService.proponerCompra(500L,
                new ProponerCompraRequest(WKT_COMERCIO, "Farmacia Central", new BigDecimal("25.00")));

        ArgumentCaptor<DatosEntrega> guardados = ArgumentCaptor.forClass(DatosEntrega.class);
        verify(datosEntregaRepository).save(guardados.capture());
        DatosEntrega datos = guardados.getValue();
        assertEquals("Farmacia Central", datos.getDetalleCompraPropuesto());
        assertEquals(new BigDecimal("25.00"), datos.getCostoProductoConfirmado());
        // Todavia no se compro nada: el cliente tiene que confirmar antes.
        assertEquals(false, datos.getCompraConfirmadaPorCliente());
        assertEquals(-68.745, datos.getPuntoCompraPropuesto().getX(), 0.000001);
    }

    @Test
    void unaPropuestaNuevaInvalidaLaConfirmacionAnterior() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_CAMINO_RECOGIDA);
        viaje.getSolicitud().getDatosEntrega().setCompraConfirmadaPorCliente(true);
        viaje.getSolicitud().getDatosEntrega().setDetalleCompraPropuesto("Farmacia Vieja");
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(viajeService.obtener(500L)).thenReturn(null);
        when(calculoPrecioDeliveryService.puedeAdelantar(any(), any())).thenReturn(true);

        entregaService.proponerCompra(500L,
                new ProponerCompraRequest(WKT_COMERCIO, "Farmacia Nueva", new BigDecimal("30.00")));

        ArgumentCaptor<DatosEntrega> guardados = ArgumentCaptor.forClass(DatosEntrega.class);
        verify(datosEntregaRepository).save(guardados.capture());
        assertEquals("Farmacia Nueva", guardados.getValue().getDetalleCompraPropuesto());
        assertEquals(false, guardados.getValue().getCompraConfirmadaPorCliente());
    }

    @Test
    void noSeProponeUnaCompraQueSuperaElLimiteDelRepartidor() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_CAMINO_RECOGIDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(calculoPrecioDeliveryService.puedeAdelantar(any(), any())).thenReturn(false);

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.proponerCompra(500L,
                        new ProponerCompraRequest(WKT_COMERCIO, "Farmacia", new BigDecimal("150.00"))));

        assertEquals(true, error.getMessage().contains("limite"));
        verify(datosEntregaRepository, never()).save(any(DatosEntrega.class));
    }

    @Test
    void elClienteConfirmaElComercioPropuesto() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_CAMINO_RECOGIDA);
        viaje.getSolicitud().getDatosEntrega().setDetalleCompraPropuesto("Farmacia Central");
        viaje.getSolicitud().getDatosEntrega().setCostoProductoConfirmado(new BigDecimal("25.00"));
        when(viajeService.obtenerViajeDelPasajero(500L)).thenReturn(viaje);
        when(viajeService.obtener(500L)).thenReturn(null);
        autenticarPasajero();

        entregaService.confirmarCompra(500L);

        ArgumentCaptor<DatosEntrega> guardados = ArgumentCaptor.forClass(DatosEntrega.class);
        verify(datosEntregaRepository).save(guardados.capture());
        assertEquals(true, guardados.getValue().getCompraConfirmadaPorCliente());
    }

    @Test
    void elClienteNoConfirmaSiElRepartidorNoPropusoNada() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_CAMINO_RECOGIDA);
        when(viajeService.obtenerViajeDelPasajero(500L)).thenReturn(viaje);
        autenticarPasajero();

        assertThrows(NegocioException.class, () -> entregaService.confirmarCompra(500L));

        verify(datosEntregaRepository, never()).save(any(DatosEntrega.class));
    }

    @Test
    void elRepartidorNoCompraSinConfirmacionDelCliente() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_CAMINO_RECOGIDA);
        viaje.getSolicitud().getDatosEntrega().setCostoProductoConfirmado(new BigDecimal("25.00"));
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.registrarCompra(500L,
                        new RegistrarCompraRequest(WKT_COMERCIO, "Farmacia Central", new BigDecimal("25.00"), null),
                        null));

        assertEquals(true, error.getMessage().contains("confirmo"));
        verify(datosEntregaRepository, never()).avanzarSiEstadoPermitido(anyLong(), anyCollection(), any());
    }

    @Test
    void unMontoRealMayorAlConfirmadoExigeUnaConfirmacionNueva() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_CAMINO_RECOGIDA);
        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        datos.setCompraConfirmadaPorCliente(true);
        datos.setCostoProductoConfirmado(new BigDecimal("25.00"));
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.registrarCompra(500L,
                        new RegistrarCompraRequest(WKT_COMERCIO, "Farmacia Central", new BigDecimal("31.00"), null),
                        null));

        assertEquals(true, error.getMessage().contains("supera"));
        verify(datosEntregaRepository, never()).avanzarSiEstadoPermitido(anyLong(), anyCollection(), any());
    }

    @Test
    void laCompraConfirmadaPoneElPedidoEnManoYCobraSoloElTrayectoDelComercioAlDestino() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_CAMINO_RECOGIDA);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        datos.setCompraConfirmadaPorCliente(true);
        datos.setCostoProductoConfirmado(new BigDecimal("25.00"));
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(datosEntregaRepository.avanzarSiEstadoPermitido(eq(1L), anyCollection(), eq(EstadoEntrega.EN_MANO)))
                .thenReturn(1);
        // El UPDATE condicional limpia el contexto: el servicio debe releer el pedido.
        when(datosEntregaRepository.findBySolicitudId(90L)).thenReturn(Optional.of(compraEnMano(viaje)));
        DesglosePrecioDelivery precio = new DesglosePrecioDelivery(new BigDecimal("9.80"),
                new BigDecimal("2.35"), 12, false);
        when(calculoPrecioDeliveryService.fijarPrecioCompra(any(), eq(viaje.getDestino()))).thenReturn(precio);

        entregaService.registrarCompra(500L,
                new RegistrarCompraRequest(WKT_COMERCIO, "Farmacia Central", new BigDecimal("25.00"), null), null);

        ArgumentCaptor<DatosEntrega> guardados = ArgumentCaptor.forClass(DatosEntrega.class);
        // El primer save es la compra; el siguiente, la ruta de la constancia del pedido.
        verify(datosEntregaRepository, org.mockito.Mockito.atLeastOnce()).save(guardados.capture());
        assertEquals(new BigDecimal("25.00"), guardados.getAllValues().get(0).getCostoProductoReal());
        assertEquals("Farmacia Central", guardados.getAllValues().get(0).getDetalleCompra());
        assertEquals(-68.745, guardados.getAllValues().get(0).getPuntoCompra().getX(), 0.000001);
        // El precio que se cobra es solo el del servicio: comercio -> destino.
        verify(viajeService).registrarPedidoEnMano(500L, precio);
    }

    @Test
    void elReciboEsOpcionalPeroSeGuardaSiViene() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_CAMINO_RECOGIDA);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        datos.setCompraConfirmadaPorCliente(true);
        datos.setCostoProductoConfirmado(new BigDecimal("25.00"));
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(datosEntregaRepository.avanzarSiEstadoPermitido(eq(1L), anyCollection(), eq(EstadoEntrega.EN_MANO)))
                .thenReturn(1);
        when(datosEntregaRepository.findBySolicitudId(90L)).thenReturn(Optional.of(compraEnMano(viaje)));
        when(calculoPrecioDeliveryService.fijarPrecioCompra(any(), any()))
                .thenReturn(new DesglosePrecioDelivery(new BigDecimal("9.80"), new BigDecimal("2.35"), 12, false));
        when(almacenamientoArchivos.carpetaEntregaViaje(any(), any())).thenReturn("personas/20_x/entrega");
        when(almacenamientoArchivos.guardarConSello(any(), anyString(), anyString(), anyString()))
                .thenReturn("personas/20_x/entrega/comprobante_1.jpg");

        entregaService.registrarCompra(500L,
                new RegistrarCompraRequest(WKT_COMERCIO, "Farmacia Central", new BigDecimal("25.00"),
                        "El comercio no dio comprobante"),
                comprobante());

        ArgumentCaptor<DatosEntrega> guardados = ArgumentCaptor.forClass(DatosEntrega.class);
        // El primer save es la compra; el siguiente, la ruta de la constancia del pedido.
        verify(datosEntregaRepository, org.mockito.Mockito.atLeastOnce()).save(guardados.capture());
        assertEquals("personas/20_x/entrega/comprobante_1.jpg", guardados.getAllValues().get(0).getFotoComprobanteUrl());
        assertEquals("El comercio no dio comprobante", guardados.getAllValues().get(0).getObservacionCompra());
    }

    @Test
    void laCompraSinReciboSeRegistraConObservacion() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_CAMINO_RECOGIDA);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        datos.setCompraConfirmadaPorCliente(true);
        datos.setCostoProductoConfirmado(new BigDecimal("25.00"));
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(datosEntregaRepository.avanzarSiEstadoPermitido(eq(1L), anyCollection(), eq(EstadoEntrega.EN_MANO)))
                .thenReturn(1);
        when(datosEntregaRepository.findBySolicitudId(90L)).thenReturn(Optional.of(compraEnMano(viaje)));
        when(calculoPrecioDeliveryService.fijarPrecioCompra(any(), any()))
                .thenReturn(new DesglosePrecioDelivery(new BigDecimal("9.80"), new BigDecimal("2.35"), 12, false));

        entregaService.registrarCompra(500L,
                new RegistrarCompraRequest(WKT_COMERCIO, "Puesto informal", new BigDecimal("25.00"),
                        "Puesto informal sin boleta"),
                null);

        ArgumentCaptor<DatosEntrega> guardados = ArgumentCaptor.forClass(DatosEntrega.class);
        // El primer save es la compra; el siguiente, la ruta de la constancia del pedido.
        verify(datosEntregaRepository, org.mockito.Mockito.atLeastOnce()).save(guardados.capture());
        assertEquals(null, guardados.getAllValues().get(0).getFotoComprobanteUrl());
        verify(almacenamientoArchivos, never()).guardarConSello(any(), anyString(), anyString(), anyString());
    }

    @Test
    void laEntregaDeUnaCompraPideLaIdentidadDelCliente() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        datos.setCompraConfirmadaPorCliente(true);
        datos.setPuntoCompra(PuntoDesdeWkt.convertir(WKT_COMERCIO));
        datos.setCostoProductoReal(new BigDecimal("25.00"));
        datos.setPagoConfirmado(true);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(datosEntregaRepository.avanzarSiEstadoPermitido(eq(1L), anyCollection(), eq(EstadoEntrega.ENTREGADO)))
                .thenReturn(1);

        when(datosEntregaRepository.findBySolicitudId(viaje.getSolicitud().getId())).thenReturn(Optional.of(datos));
        entregaService.entregarConReceptor(500L, new IdentificarReceptorRequest(" pasajera  prueba ", "71234567", -11.03, -68.74), foto());

        verify(viajeService).finalizarDesdeEntrega(eq(500L), any());
    }

    @Test
    void otraPersonaNoPuedeFirmarLaEntregaDeUnaCompra() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        // El pago ya esta confirmado: lo que se prueba aqui es solo quien firma.
        viaje.getSolicitud().getDatosEntrega().setPagoConfirmado(true);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.entregarConReceptor(500L,
                        new IdentificarReceptorRequest("Otro Persona", "71234567", -11.03, -68.74), foto()));

        assertEquals(true, error.getMessage().contains("nombre"));
        verify(datosEntregaRepository, never()).avanzarSiEstadoPermitido(anyLong(), anyCollection(), any());
    }

    @Test
    void unTelefonoDistintoTampocoDejaFirmar() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        viaje.getSolicitud().getDatosEntrega().setPagoConfirmado(true);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        assertThrows(NegocioException.class,
                () -> entregaService.entregarConReceptor(500L,
                        new IdentificarReceptorRequest("Pasajera Prueba", "79999999", -11.03, -68.74), foto()));

        verify(datosEntregaRepository, never()).avanzarSiEstadoPermitido(anyLong(), anyCollection(), any());
    }

    @Test
    void sinTelefonoRegistradoSoloSeExigeElNombre() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        viaje.getPasajero().getUsuario().getPersona().setTelefono(null);
        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        datos.setCompraConfirmadaPorCliente(true);
        datos.setPuntoCompra(PuntoDesdeWkt.convertir(WKT_COMERCIO));
        datos.setCostoProductoReal(new BigDecimal("25.00"));
        datos.setPagoConfirmado(true);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(datosEntregaRepository.avanzarSiEstadoPermitido(eq(1L), anyCollection(), eq(EstadoEntrega.ENTREGADO)))
                .thenReturn(1);

        when(datosEntregaRepository.findBySolicitudId(viaje.getSolicitud().getId())).thenReturn(Optional.of(datos));
        entregaService.entregarConReceptor(500L, new IdentificarReceptorRequest("Pasajera Prueba", null, -11.03, -68.74), foto());

        verify(viajeService).finalizarDesdeEntrega(eq(500L), any());
    }

    private MultipartFile foto() {
        return new MockMultipartFile("foto", "entrega.png", "image/png", imagenPng());
    }

    /** Comprobante real: ProcesadorImagen rechaza los bytes que no son una imagen. */
    private MultipartFile comprobante() {
        return new MockMultipartFile("comprobante", "recibo.png", "image/png", imagenPng());
    }

    private byte[] imagenPng() {
        try {
            BufferedImage imagen = new BufferedImage(8, 8, BufferedImage.TYPE_INT_RGB);
            ByteArrayOutputStream salida = new ByteArrayOutputStream();
            ImageIO.write(imagen, "png", salida);
            return salida.toByteArray();
        } catch (java.io.IOException e) {
            throw new IllegalStateException(e);
        }
    }

    private Viaje viajeCompra(EstadoEntrega estadoEntrega) {
        CategoriaServicio delivery = new CategoriaServicio();
        delivery.setId(7);
        delivery.setNombre("DELIVERY");
        delivery.setTipoVehiculo(new TipoVehiculo());

        Pasajero pasajero = new Pasajero();
        pasajero.setId(30L);
        pasajero.setUsuario(usuario(10L, "Pasajera", "71234567"));

        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setId(90L);
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(delivery);
        solicitud.setOrigen(punto(-68.75, -11.02));
        solicitud.setDestino(punto(-68.74, -11.03));

        DatosEntrega datos = new DatosEntrega();
        datos.setId(1L);
        datos.setSolicitud(solicitud);
        datos.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        datos.setDescripcion("Medicamento");
        datos.setCostoProductoEstimado(new BigDecimal("25.00"));
        datos.setEstadoEntrega(estadoEntrega);
        solicitud.setDatosEntrega(datos);

        Viaje viaje = new Viaje();
        viaje.setId(500L);
        viaje.setSolicitud(solicitud);
        viaje.setPasajero(pasajero);
        viaje.setConductor(conductor);
        viaje.setCategoriaServicio(delivery);
        viaje.setOrigen(solicitud.getOrigen());
        viaje.setDestino(solicitud.getDestino());
        viaje.setPrecioFinal(new BigDecimal("9.80"));
        viaje.setSituacionViaje(SituacionViaje.CONFIRMADO);
        return viaje;
    }

    private DatosEntrega compraEnMano(Viaje viaje) {
        DatosEntrega datos = new DatosEntrega();
        datos.setId(1L);
        datos.setSolicitud(viaje.getSolicitud());
        datos.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        datos.setDescripcion("Medicamento");
        datos.setCostoProductoEstimado(new BigDecimal("25.00"));
        datos.setEstadoEntrega(EstadoEntrega.EN_MANO);
        return datos;
    }

    private Usuario usuario(Long id, String nombre, String telefono) {
        Persona persona = new Persona();
        persona.setNombres(nombre);
        persona.setApellidos("Prueba");
        persona.setTelefono(telefono);
        Usuario usuario = new Usuario();
        usuario.setId(id);
        usuario.setPersona(persona);
        return usuario;
    }

    private void autenticarPasajero() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtUser(10L, "pasajera", "PASAJERO"), null));
    }

    private Point punto(double longitud, double latitud) {
        return GEOMETRIA.createPoint(new Coordinate(longitud, latitud));
    }
}