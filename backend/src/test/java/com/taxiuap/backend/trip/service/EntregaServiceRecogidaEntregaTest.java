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
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.pricing.dto.DesglosePrecioDelivery;
import com.taxiuap.backend.pricing.repository.PagoRepository;
import com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryService;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.dto.ConfirmarPagoEntregaRequest;
import com.taxiuap.backend.trip.dto.IdentificarReceptorRequest;
import com.taxiuap.backend.trip.dto.ValidarCodigoEntregaRequest;
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
 * ENCOMIENDA: el repartidor valida en A el codigo que le dicta el remitente y en B el que le dicta el
 * receptor, y no entrega nada sin confirmar antes el pago. Cada transicion se comprueba en la base de
 * datos con un UPDATE condicional, no leyendo y luego guardando.
 */
@ExtendWith(MockitoExtension.class)
class EntregaServiceRecogidaEntregaTest {

    private static final GeometryFactory GEOMETRIA = new GeometryFactory(new PrecisionModel(), 4326);

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
        autenticarConductor();
    }

    @AfterEach
    void limpiarSeguridad() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void elCodigoDeRecogidaCorrectoPoneElPedidoEnMano() {
        Viaje viaje = viajeEncomienda(SituacionViaje.CONDUCTOR_LLEGO, EstadoEntrega.EN_CAMINO_RECOGIDA);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        // El UPDATE condicional (estado + codigo) actualiza una fila.
        when(datosEntregaRepository.avanzarSiCodigoRecogidaCoincide(eq(1L), anyCollection(), eq(EstadoEntrega.EN_MANO),
                eq("123456"))).thenReturn(1);

        when(datosEntregaRepository.findBySolicitudId(90L))
                .thenReturn(Optional.of(viaje.getSolicitud().getDatosEntrega()));
        when(almacenamientoArchivos.guardarConSello(any(), any(), eq("recogida"), eq("jpg")))
                .thenReturn("personas/1/conductor/entrega/viaje_500/recogida_1.jpg");

        entregaService.validarRecogida(500L, new ValidarCodigoEntregaRequest("123456", -11.02, -68.75), foto());

        // El pedido ya esta en manos del repartidor, asi que el viaje empieza su curso real.
        verify(viajeService).registrarPedidoEnMano(500L, null);
        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        assertEquals("personas/1/conductor/entrega/viaje_500/recogida_1.jpg", datos.getFotoRecogidaUrl());
        assertEquals(true, datos.getFechaRecogida() != null);
        assertEquals(-11.02, datos.getUbicacionRecogida().getY());
        // El cliente recibe el aviso de que su paquete va en camino.
        verify(viajeService).avisarPasajero(eq(viaje), eq("PAQUETE_RECOGIDO"), anyString(), anyString());
    }

    @Test
    void sinMarcarLaLlegadaAlPuntoDeRecogidaNoSeRecogeElPaquete() {
        Viaje viaje = viajeEncomienda(SituacionViaje.CONFIRMADO, EstadoEntrega.EN_CAMINO_RECOGIDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.validarRecogida(500L, new ValidarCodigoEntregaRequest("123456"), foto()));

        assertEquals(true, error.getMessage().contains("llegaste al punto de recogida"));
        verify(datosEntregaRepository, never()).avanzarSiCodigoRecogidaCoincide(anyLong(), anyCollection(), any(),
                anyString());
    }

    @Test
    void sinFotoDelPaqueteNoSeRecoge() {
        Viaje viaje = viajeEncomienda(SituacionViaje.CONDUCTOR_LLEGO, EstadoEntrega.EN_CAMINO_RECOGIDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.validarRecogida(500L, new ValidarCodigoEntregaRequest("123456"), null));

        assertEquals(true, error.getMessage().contains("foto del paquete"));
        verify(datosEntregaRepository, never()).avanzarSiCodigoRecogidaCoincide(anyLong(), anyCollection(), any(),
                anyString());
    }

    @Test
    void marcarLaLlegadaAlPuntoDeRecogidaGuardaLaHoraYAvanzaElViaje() {
        Viaje viaje = viajeEncomienda(SituacionViaje.CONFIRMADO, EstadoEntrega.EN_CAMINO_RECOGIDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        entregaService.llegadaRecogida(500L);

        assertEquals(true, viaje.getSolicitud().getDatosEntrega().getFechaLlegadaRecogida() != null);
        verify(viajeService).llegadaRecogida(500L);
    }

    @Test
    void lejosDelDestinoNoSeConfirmaLaEntrega() {
        Viaje viaje = viajeEncomienda(SituacionViaje.EN_CURSO, EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setPagoConfirmado(true);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        // El origen esta a unos 1,5 km del destino.
        NegocioException error = assertThrows(NegocioException.class, () -> entregaService.entregarConCodigo(500L,
                new ValidarCodigoEntregaRequest("654321", -11.02, -68.75), foto()));

        assertEquals(true, error.getMessage().contains("m del destino"));
        verify(datosEntregaRepository, never()).avanzarSiCodigoEntregaCoincide(anyLong(), anyCollection(), any(),
                anyString());
    }

    @Test
    void sinFotoDeLaEntregaNoSeCompletaElViaje() {
        Viaje viaje = viajeEncomienda(SituacionViaje.EN_CURSO, EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setPagoConfirmado(true);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.entregarConCodigo(500L, enDestino("654321"), null));

        assertEquals(true, error.getMessage().contains("foto de la entrega"));
        verify(viajeService, never()).finalizarDesdeEntrega(anyLong(), any());
    }

    @Test
    void laConstanciaTieneCadaConfirmacionPeroNuncaLosCodigos() {
        Viaje viaje = viajeEncomienda(SituacionViaje.COMPLETADO, EstadoEntrega.ENTREGADO);
        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        datos.setFechaRecogida(java.time.LocalDateTime.of(2026, 10, 6, 10, 0));
        datos.setFotoRecogidaUrl("personas/1/conductor/entrega/viaje_500/recogida_20261006_100000.jpg");
        datos.setFechaEntrega(java.time.LocalDateTime.of(2026, 10, 6, 10, 20));
        datos.setFotoEntregaUrl("personas/1/conductor/entrega/viaje_500/entrega_20261006_102000.jpg");
        datos.setUbicacionEntrega(punto(-68.74, -11.03));

        String texto = EntregaService.textoConstancia(viaje, datos);

        assertEquals(true, texto.contains("Paquete recogido"));
        assertEquals(true, texto.contains("recogida_20261006_100000.jpg"));
        assertEquals(true, texto.contains("Paquete entregado"));
        assertEquals(true, texto.contains("entrega_20261006_102000.jpg"));
        assertEquals(false, texto.contains("123456"));
        assertEquals(false, texto.contains("654321"));
    }


    @Test
    void unCodigoDeRecogidaIncorrectoNoAvanzaElPedido() {
        Viaje viaje = viajeEncomienda(SituacionViaje.CONDUCTOR_LLEGO, EstadoEntrega.EN_CAMINO_RECOGIDA);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        // El UPDATE condicional no toca ninguna fila: el codigo no coincidia.
        when(datosEntregaRepository.avanzarSiCodigoRecogidaCoincide(eq(1L), anyCollection(), eq(EstadoEntrega.EN_MANO),
                eq("000000"))).thenReturn(0);
        when(datosEntregaRepository.findById(1L))
                .thenReturn(Optional.of(viaje.getSolicitud().getDatosEntrega()));

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.validarRecogida(500L, new ValidarCodigoEntregaRequest("000000"), foto()));

        assertEquals(true, error.getMessage().contains("codigo de recogida"));
        verify(viajeService, never()).registrarPedidoEnMano(anyLong(), any());
    }

    @Test
    void elCodigoDeRecogidaNoSePuedeUsarDosVeces() {
        Viaje viaje = viajeEncomienda(SituacionViaje.CONDUCTOR_LLEGO, EstadoEntrega.EN_CAMINO_RECOGIDA);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(datosEntregaRepository.avanzarSiCodigoRecogidaCoincide(eq(1L), anyCollection(), eq(EstadoEntrega.EN_MANO),
                eq("123456"))).thenReturn(0);
        // El pedido ya estaba en mano: la segunda pulsacion es una repeticion, no un error de codigo.
        when(datosEntregaRepository.findById(1L)).thenReturn(Optional.of(
                encomiendaEnMano(viaje.getSolicitud().getDatosEntrega())));

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.validarRecogida(500L, new ValidarCodigoEntregaRequest("123456"), foto()));

        assertEquals(true, error.getMessage().contains("Transicion de estado no permitida"));
    }

    @Test
    void elCodigoSeComparaEnLaBaseDeDatosYNoConUnGuardadoSuelto() {
        Viaje viaje = viajeEncomienda(SituacionViaje.CONDUCTOR_LLEGO, EstadoEntrega.EN_CAMINO_RECOGIDA);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        // 654321 es el codigo de entrega, no el de recogida: el UPDATE condicional no toca ninguna fila.
        when(datosEntregaRepository.avanzarSiCodigoRecogidaCoincide(eq(1L), anyCollection(), eq(EstadoEntrega.EN_MANO),
                eq("654321"))).thenReturn(0);
        when(datosEntregaRepository.findById(1L)).thenReturn(Optional.of(viaje.getSolicitud().getDatosEntrega()));

        assertThrows(NegocioException.class,
                () -> entregaService.validarRecogida(500L, new ValidarCodigoEntregaRequest("654321"), foto()));

        // Ni un save ni un arranque de viaje: el codigo jamas se comparo en Java, que es donde dos
        // pantallas simultaneas podrian pasar las dos.
        verify(datosEntregaRepository, never()).save(any(DatosEntrega.class));
        verify(viajeService, never()).registrarPedidoEnMano(anyLong(), any());
    }

    @Test
    void elCodigoDeEntregaYElPagoConfirmadoCompletanElViaje() {
        Viaje viaje = viajeEncomienda(SituacionViaje.EN_CURSO, EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        viaje.getSolicitud().getDatosEntrega().setPagoConfirmado(true);
        viaje.getSolicitud().getDatosEntrega().setMontoPagoRecibido(new BigDecimal("17.50"));
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(datosEntregaRepository.avanzarSiCodigoEntregaCoincide(eq(1L), anyCollection(), eq(EstadoEntrega.ENTREGADO),
                eq("654321"))).thenReturn(1);

        when(datosEntregaRepository.findBySolicitudId(90L))
                .thenReturn(Optional.of(viaje.getSolicitud().getDatosEntrega()));
        when(almacenamientoArchivos.guardarConSello(any(), any(), eq("entrega"), eq("jpg")))
                .thenReturn("personas/1/conductor/entrega/viaje_500/entrega_1.jpg");

        entregaService.entregarConCodigo(500L, enDestino("654321"), foto());

        verify(viajeService).finalizarDesdeEntrega(eq(500L), any());
        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        assertEquals("personas/1/conductor/entrega/viaje_500/entrega_1.jpg", datos.getFotoEntregaUrl());
        assertEquals(true, datos.getFechaEntrega() != null);
        verify(viajeService).avisarPasajero(eq(viaje), eq("PAQUETE_ENTREGADO"), anyString(), anyString());
    }

    @Test
    void unCodigoDeEntregaIncorrectoNoCompletaElViaje() {
        Viaje viaje = viajeEncomienda(SituacionViaje.EN_CURSO, EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        viaje.getSolicitud().getDatosEntrega().setPagoConfirmado(true);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(datosEntregaRepository.avanzarSiCodigoEntregaCoincide(eq(1L), anyCollection(), eq(EstadoEntrega.ENTREGADO),
                eq("111111"))).thenReturn(0);
        when(datosEntregaRepository.findById(1L)).thenReturn(Optional.of(viaje.getSolicitud().getDatosEntrega()));

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.entregarConCodigo(500L, enDestino("111111"), foto()));

        assertEquals(true, error.getMessage().contains("codigo de entrega"));
        verify(viajeService, never()).finalizarDesdeEntrega(anyLong(), any());
    }

    @Test
    void noSeEntregaSinHaberConfirmadoElPago() {
        Viaje viaje = viajeEncomienda(SituacionViaje.EN_CURSO, EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.entregarConCodigo(500L, enDestino("654321"), foto()));

        assertEquals(true, error.getMessage().contains("pago"));
        verify(datosEntregaRepository, never()).avanzarSiCodigoEntregaCoincide(anyLong(), anyCollection(), any(),
                anyString());
    }

    @Test
    void elPagoRegistradoDebeSerElTotalACobrar() {
        Viaje viaje = viajeEncomienda(SituacionViaje.EN_CURSO, EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.confirmarPago(500L, new ConfirmarPagoEntregaRequest(new BigDecimal("5.00"), null)));

        assertEquals(true, error.getMessage().contains("17.50"));
    }

    @Test
    void confirmarElPagoGuardaElTotalYAvisaQueSeCobroEnElDestino() {
        Viaje viaje = viajeEncomienda(SituacionViaje.EN_CURSO, EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(viajeService.obtener(500L)).thenReturn(null);

        when(datosEntregaRepository.confirmarPagoSiEnMano(eq(1L), eq(EstadoEntrega.EN_MANO), eq(new BigDecimal("17.50"))))
                .thenReturn(1);
        entregaService.confirmarPago(500L, new ConfirmarPagoEntregaRequest(new BigDecimal("17.50"), null));

        verify(datosEntregaRepository).confirmarPagoSiEnMano(eq(1L), eq(EstadoEntrega.EN_MANO), eq(new BigDecimal("17.50")));
        verify(datosEntregaRepository, org.mockito.Mockito.never()).save(any());
    }

    @Test
    void soloElConductorAsignadoPuedeAvanzarElPedido() {
        // obtenerViajeDelConductor ya responde "no encontrado" si el viaje es de otro conductor:
        // aqui se comprueba que EntregaService no busca el pedido por otra via.
        when(viajeService.obtenerViajeDelConductor(500L))
                .thenThrow(new NegocioException("Viaje no encontrado"));

        assertThrows(NegocioException.class,
                () -> entregaService.validarRecogida(500L, new ValidarCodigoEntregaRequest("123456"), foto()));
    }

    @Test
    void laEncomiendaNoSeEntregaIdentificandoAlReceptor() {
        Viaje viaje = viajeEncomienda(SituacionViaje.EN_CURSO, EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        // En ENCOMIENDA manda el codigo de entrega, nunca la identidad del receptor.
        assertThrows(NegocioException.class, () -> entregaService.entregarConReceptor(500L,
                new IdentificarReceptorRequest("Pasajera Prueba", "70000001", -11.03, -68.74), foto()));
    }

    @Test
    void laRecogidaNoUsaElInicioGenericoDelTaxi() {
        Viaje viaje = viajeEncomienda(SituacionViaje.CONDUCTOR_LLEGO, EstadoEntrega.EN_CAMINO_RECOGIDA);
        viaje.getSolicitud().getDatosEntrega().setId(1L);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(datosEntregaRepository.avanzarSiCodigoRecogidaCoincide(eq(1L), anyCollection(), eq(EstadoEntrega.EN_MANO),
                eq("123456"))).thenReturn(1);

        when(datosEntregaRepository.findBySolicitudId(90L))
                .thenReturn(Optional.of(viaje.getSolicitud().getDatosEntrega()));

        entregaService.validarRecogida(500L, new ValidarCodigoEntregaRequest("123456"), foto());

        // La recogida no usa iniciar(): el viaje pasa a EN_CURSO por registrarPedidoEnMano.
        verify(viajeService).registrarPedidoEnMano(500L, null);
        verify(viajeService, never()).iniciar(anyLong());
    }

    private Viaje viajeEncomienda(SituacionViaje situacion, EstadoEntrega estadoEntrega) {
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
        datos.setSolicitud(solicitud);
        datos.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        datos.setDescripcion("Documentos");
        datos.setCostoProductoEstimado(BigDecimal.ZERO);
        datos.setCodigoRecogida("123456");
        datos.setCodigoEntrega("654321");
        datos.setAceptaPoliticaArticulos(true);
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
        viaje.setPrecioFinal(new BigDecimal("17.50"));
        viaje.setSituacionViaje(situacion);
        return viaje;
    }

    private DatosEntrega encomiendaEnMano(DatosEntrega original) {
        DatosEntrega datos = new DatosEntrega();
        datos.setId(original.getId());
        datos.setTipoEnvio(original.getTipoEnvio());
        datos.setDescripcion(original.getDescripcion());
        datos.setCostoProductoEstimado(original.getCostoProductoEstimado());
        datos.setCodigoRecogida(original.getCodigoRecogida());
        datos.setCodigoEntrega(original.getCodigoEntrega());
        datos.setAceptaPoliticaArticulos(true);
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

    private void autenticarConductor() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtUser(20L, "repartidor", "CONDUCTOR"), null));
    }

    /** Codigo dictado con el GPS del repartidor justo en el destino (B). */
    private ValidarCodigoEntregaRequest enDestino(String codigo) {
        return new ValidarCodigoEntregaRequest(codigo, -11.03, -68.74);
    }

    private MultipartFile foto() {
        try {
            BufferedImage imagen = new BufferedImage(8, 8, BufferedImage.TYPE_INT_RGB);
            ByteArrayOutputStream salida = new ByteArrayOutputStream();
            ImageIO.write(imagen, "png", salida);
            return new MockMultipartFile("foto", "foto.png", "image/png", salida.toByteArray());
        } catch (java.io.IOException e) {
            throw new IllegalStateException(e);
        }
    }

    private Point punto(double longitud, double latitud) {
        return GEOMETRIA.createPoint(new Coordinate(longitud, latitud));
    }
}