package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
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

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.util.List;
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
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.ConflictoException;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.dto.IdentificarReceptorRequest;
import com.taxiuap.backend.trip.dto.AceptarCostoRequest;
import com.taxiuap.backend.trip.dto.ConfirmarPagoEntregaRequest;
import com.taxiuap.backend.trip.dto.ProductoCompradoRequest;
import com.taxiuap.backend.trip.dto.RegistrarCompraRequest;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.ProductoEntrega;
import com.taxiuap.backend.trip.entity.PropuestaCostoEntrega;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.SituacionProducto;
import com.taxiuap.backend.trip.enums.SituacionPropuestaCosto;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.trip.repository.DatosEntregaRepository;
import com.taxiuap.backend.trip.repository.ProductoEntregaRepository;
import com.taxiuap.backend.trip.repository.PropuestaCostoEntregaRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;

/**
 * COMPRA_Y_ENTREGA: el repartidor registra cada producto (conseguido con su precio o no), el servidor
 * calcula el total y el cliente acepta esa version exacta del costo. Corregir los precios antes del pago
 * anula la aceptacion; sin aceptacion no se cobra ni se entrega. El servicio se cobra desde el comercio.
 */
@ExtendWith(MockitoExtension.class)
class EntregaServiceCompraTest {

    private static final GeometryFactory GEOMETRIA = new GeometryFactory(new PrecisionModel(), 4326);
    private static final String WKT_COMERCIO = "POINT(-68.745 -11.025)";

    @Mock private ViajeService viajeService;
    @Mock private DatosEntregaRepository datosEntregaRepository;
    @Mock private CalculoPrecioDeliveryService calculoPrecioDeliveryService;
    @Mock private AlmacenamientoArchivos almacenamientoArchivos;
    @Mock private ProductoEntregaRepository productoRepository;
    @Mock private PropuestaCostoEntregaRepository propuestaRepository;

    private EntregaService entregaService;
    private Conductor conductor;
    private ProductoEntrega pan;
    private ProductoEntrega leche;
    private DatosEntrega enMano;

    @BeforeEach
    void setUp() {
        entregaService = new EntregaService(viajeService, datosEntregaRepository,
                calculoPrecioDeliveryService, almacenamientoArchivos, null, productoRepository, propuestaRepository);
        pan = producto(11L, "Pan", 2);
        leche = producto(12L, "Leche", 1);
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
    void lasAppsViejasQueProponenLaCompraRecibenElAvisoDeActualizar() {
        NegocioException error = assertThrows(NegocioException.class, () -> entregaService.compraConFlujoAnterior());

        assertTrue(error.getMessage().contains("Actualiza UNITAXI"));
    }

    @Test
    void registrarLaCompraCalculaLosSubtotalesYPresentaLaPrimeraVersionDelCosto() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_CAMINO_RECOGIDA);
        prepararRegistro(viaje);
        when(datosEntregaRepository.avanzarSiEstadoPermitido(eq(1L), anyCollection(), eq(EstadoEntrega.EN_MANO)))
                .thenReturn(1);
        DesglosePrecioDelivery precio = new DesglosePrecioDelivery(new BigDecimal("9.80"),
                new BigDecimal("2.35"), 12, false);
        when(calculoPrecioDeliveryService.fijarPrecioCompra(any(), eq(viaje.getDestino()), any())).thenReturn(precio);
        when(propuestaRepository.findFirstByDatosEntregaIdOrderByVersionDesc(1L)).thenReturn(Optional.empty());

        entregaService.registrarCompra(500L, compra(
                new ProductoCompradoRequest(11L, true, 2, new BigDecimal("5"), null),
                new ProductoCompradoRequest(12L, false, null, null, "No habia")), null);

        // El precio del servicio se fija desde el comercio (solo la primera vez).
        verify(viajeService).registrarPedidoEnMano(500L, precio);
        assertEquals(SituacionProducto.CONSEGUIDO, pan.getSituacionProducto());
        assertEquals(new BigDecimal("10.00"), pan.getSubtotal());
        assertEquals(SituacionProducto.NO_CONSEGUIDO, leche.getSituacionProducto());
        assertEquals(new BigDecimal("0.00"), leche.getSubtotal());
        assertEquals(new BigDecimal("10.00"), enMano.getCostoProductoReal());
        PropuestaCostoEntrega propuesta = propuestaGuardada();
        assertEquals(1, propuesta.getVersion());
        assertEquals(new BigDecimal("9.80"), propuesta.getPrecioServicio());
        assertEquals(new BigDecimal("10.00"), propuesta.getTotalProductos());
        assertEquals(new BigDecimal("19.80"), propuesta.getTotal());
        assertEquals(SituacionPropuestaCosto.PENDIENTE, propuesta.getSituacionPropuesta());
        assertTrue(propuesta.getDetalleJson().contains("No habia"));
        verify(viajeService).avisarPasajero(eq(viaje), eq("COSTO_POR_APROBAR"), anyString(), anyString(),
                eq(java.util.Map.of("version", "1")));
    }

    @Test
    void unaAppViejaQueRegistraSinLaListaRecibeElAvisoDeActualizar() {
        NegocioException error = assertThrows(NegocioException.class, () -> entregaService.registrarCompra(500L,
                new RegistrarCompraRequest(WKT_COMERCIO, "Tienda Central", null, null), null));

        assertTrue(error.getMessage().contains("Actualiza UNITAXI"));
        verify(datosEntregaRepository, never()).avanzarSiEstadoPermitido(anyLong(), anyCollection(), any());
    }

    @Test
    void laConfirmacionDeAntesDeComprarNoCuentaComoCostoAceptado() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_CAMINO_RECOGIDA);
        prepararRegistro(viaje);
        // Pedido del flujo anterior: el cliente habia confirmado antes de que el repartidor comprara.
        enMano.setCompraConfirmadaPorCliente(true);
        enMano.setCostoProductoConfirmado(new BigDecimal("30.00"));
        when(datosEntregaRepository.avanzarSiEstadoPermitido(eq(1L), anyCollection(), eq(EstadoEntrega.EN_MANO)))
                .thenReturn(1);
        when(calculoPrecioDeliveryService.fijarPrecioCompra(any(), eq(viaje.getDestino()), any()))
                .thenReturn(new DesglosePrecioDelivery(new BigDecimal("9.80"), new BigDecimal("2.35"), 12, false));
        when(propuestaRepository.findFirstByDatosEntregaIdOrderByVersionDesc(1L)).thenReturn(Optional.empty());

        entregaService.registrarCompra(500L, compra(
                new ProductoCompradoRequest(11L, true, 1, new BigDecimal("5"), null),
                new ProductoCompradoRequest(12L, false, null, null, null)), null);

        assertEquals(Boolean.FALSE, enMano.getCompraConfirmadaPorCliente());
        assertEquals(null, enMano.getCostoProductoConfirmado());
        assertEquals(SituacionPropuestaCosto.PENDIENTE, propuestaGuardada().getSituacionPropuesta());
    }

    @Test
    void faltaResponderPorUnProductoYNoSeRegistraNada() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_CAMINO_RECOGIDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(productoRepository.findByDatosEntregaIdAndEstadoProductoEntregaOrderByOrdenAscIdAsc(1L, EstadoRegistro.A))
                .thenReturn(List.of(pan, leche));

        NegocioException error = assertThrows(NegocioException.class, () -> entregaService.registrarCompra(500L,
                compra(new ProductoCompradoRequest(11L, true, 2, new BigDecimal("5"), null)), null));

        assertTrue(error.getMessage().contains("cada producto"));
        verify(datosEntregaRepository, never()).avanzarSiEstadoPermitido(anyLong(), anyCollection(), any());
    }

    @Test
    void sinNingunProductoConseguidoNoHayCompraQueCobrar() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_CAMINO_RECOGIDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(productoRepository.findByDatosEntregaIdAndEstadoProductoEntregaOrderByOrdenAscIdAsc(1L, EstadoRegistro.A))
                .thenReturn(List.of(pan, leche));

        NegocioException error = assertThrows(NegocioException.class, () -> entregaService.registrarCompra(500L,
                compra(new ProductoCompradoRequest(11L, false, null, null, null),
                        new ProductoCompradoRequest(12L, false, null, null, null)), null));

        assertTrue(error.getMessage().contains("ningún producto"));
        verify(datosEntregaRepository, never()).avanzarSiEstadoPermitido(anyLong(), anyCollection(), any());
    }

    @Test
    void corregirLosPreciosAntesDelPagoAnulaLaAceptacionYPresentaOtraVersion() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setCompraConfirmadaPorCliente(true);
        prepararRegistro(viaje);
        when(datosEntregaRepository.invalidarAprobacionSiSinPago(1L)).thenReturn(1);
        PropuestaCostoEntrega anterior = new PropuestaCostoEntrega();
        anterior.setVersion(1);
        when(propuestaRepository.findFirstByDatosEntregaIdOrderByVersionDesc(1L)).thenReturn(Optional.of(anterior));

        entregaService.registrarCompra(500L, compra(
                new ProductoCompradoRequest(11L, true, 2, new BigDecimal("6.50"), null),
                new ProductoCompradoRequest(12L, true, 1, new BigDecimal("8"), null)), null);

        verify(propuestaRepository).reemplazarVigentes(eq(1L), anyCollection());
        PropuestaCostoEntrega propuesta = propuestaGuardada();
        assertEquals(2, propuesta.getVersion());
        assertEquals(new BigDecimal("21.00"), propuesta.getTotalProductos());
        assertEquals(new BigDecimal("30.80"), propuesta.getTotal());
        // El servicio ya estaba fijado: una correccion no lo recalcula.
        verify(viajeService, never()).registrarPedidoEnMano(anyLong(), any());
        verify(calculoPrecioDeliveryService, never()).fijarPrecioCompra(any(), any(), any());
    }

    @Test
    void conElPagoConfirmadoYaNoSeCorrigenLosPrecios() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setPagoConfirmado(true);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException error = assertThrows(NegocioException.class, () -> entregaService.registrarCompra(500L,
                compra(new ProductoCompradoRequest(11L, true, 2, new BigDecimal("5"), null)), null));

        assertTrue(error.getMessage().contains("pago ya fue confirmado"));
        verify(datosEntregaRepository, never()).invalidarAprobacionSiSinPago(anyLong());
    }

    @Test
    void elClienteAceptaLaVersionQueVio() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_MANO);
        when(viajeService.obtenerViajeDelPasajero(500L)).thenReturn(viaje);
        PropuestaCostoEntrega vigente = propuesta(3L, 2, SituacionPropuestaCosto.PENDIENTE);
        when(propuestaRepository.findFirstByDatosEntregaIdOrderByVersionDesc(1L)).thenReturn(Optional.of(vigente));
        when(propuestaRepository.aceptarSiPendiente(eq(3L), eq(viaje.getPasajero().getUsuario()), any())).thenReturn(1);
        when(datosEntregaRepository.marcarCostoAprobado(1L, new BigDecimal("10.00"))).thenReturn(1);

        entregaService.aceptarCosto(500L, new AceptarCostoRequest(2));

        verify(datosEntregaRepository).marcarCostoAprobado(1L, new BigDecimal("10.00"));
        verify(viajeService).avisarConductor(eq(viaje), eq("COSTO_ACEPTADO"), anyString(), anyString());
    }

    @Test
    void unaVersionViejaNoSeAcepta() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_MANO);
        when(viajeService.obtenerViajeDelPasajero(500L)).thenReturn(viaje);
        when(propuestaRepository.findFirstByDatosEntregaIdOrderByVersionDesc(1L))
                .thenReturn(Optional.of(propuesta(3L, 2, SituacionPropuestaCosto.PENDIENTE)));

        assertThrows(ConflictoException.class, () -> entregaService.aceptarCosto(500L, new AceptarCostoRequest(1)));

        verify(propuestaRepository, never()).aceptarSiPendiente(anyLong(), any(), any());
        verify(datosEntregaRepository, never()).marcarCostoAprobado(anyLong(), any());
    }

    @Test
    void siElRepartidorCorrigeAlMismoTiempoLaAceptacionNoVale() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_MANO);
        when(viajeService.obtenerViajeDelPasajero(500L)).thenReturn(viaje);
        when(propuestaRepository.findFirstByDatosEntregaIdOrderByVersionDesc(1L))
                .thenReturn(Optional.of(propuesta(3L, 2, SituacionPropuestaCosto.PENDIENTE)));
        when(propuestaRepository.aceptarSiPendiente(eq(3L), any(), any())).thenReturn(0);

        assertThrows(ConflictoException.class, () -> entregaService.aceptarCosto(500L, new AceptarCostoRequest(2)));

        verify(datosEntregaRepository, never()).marcarCostoAprobado(anyLong(), any());
    }

    @Test
    void aceptarDosVecesLaMismaVersionNoHaceNadaLaSegunda() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_MANO);
        when(viajeService.obtenerViajeDelPasajero(500L)).thenReturn(viaje);
        when(propuestaRepository.findFirstByDatosEntregaIdOrderByVersionDesc(1L))
                .thenReturn(Optional.of(propuesta(3L, 2, SituacionPropuestaCosto.ACEPTADA)));

        entregaService.aceptarCosto(500L, new AceptarCostoRequest(2));

        verify(propuestaRepository, never()).aceptarSiPendiente(anyLong(), any(), any());
        verify(viajeService, never()).avisarConductor(any(), anyString(), anyString(), anyString());
    }

    @Test
    void sinElCostoAceptadoNoSeCobraLaCompra() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setCostoProductoReal(new BigDecimal("10.00"));
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException error = assertThrows(NegocioException.class, () -> entregaService.confirmarPago(500L,
                new ConfirmarPagoEntregaRequest(new BigDecimal("19.80"), null)));

        assertEquals(EntregaService.MENSAJE_COSTO_SIN_ACEPTAR, error.getMessage());
        verify(datosEntregaRepository, never()).confirmarPagoSiEnMano(anyLong(), any(), any());
    }

    @Test
    void sinElCostoAceptadoNoSeEntregaLaCompra() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_MANO);
        viaje.getSolicitud().getDatosEntrega().setPagoConfirmado(true);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException error = assertThrows(NegocioException.class, () -> entregaService.entregarConReceptor(500L,
                new IdentificarReceptorRequest("Pasajera Prueba", "71234567", -11.03, -68.74), foto()));

        assertEquals(EntregaService.MENSAJE_COSTO_SIN_ACEPTAR, error.getMessage());
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
        // El costo y el pago ya estan confirmados: lo que se prueba aqui es solo quien firma.
        viaje.getSolicitud().getDatosEntrega().setCompraConfirmadaPorCliente(true);
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
        viaje.getSolicitud().getDatosEntrega().setCompraConfirmadaPorCliente(true);
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

    @Test
    void unaCompraParaOtraPersonaLaFirmaQuienRecibeConSuCelular() {
        Viaje viaje = viajeCompra(EstadoEntrega.EN_MANO);
        viaje.getSolicitud().setParaOtraPersona(true);
        viaje.getSolicitud().setNombrePasajeroTercero("JUAN PEREZ");
        viaje.getSolicitud().setTelefonoPasajeroTercero("72223333");
        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        datos.setId(1L);
        datos.setCompraConfirmadaPorCliente(true);
        datos.setPuntoCompra(PuntoDesdeWkt.convertir(WKT_COMERCIO));
        datos.setCostoProductoReal(new BigDecimal("25.00"));
        datos.setPagoConfirmado(true);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        // El celular del cliente no sirve: recibe Juan.
        NegocioException error = assertThrows(NegocioException.class, () -> entregaService.entregarConReceptor(500L,
                new IdentificarReceptorRequest("Pasajera Prueba", "71234567", -11.03, -68.74), foto()));
        assertEquals(true, error.getMessage().contains("Juan"));

        when(datosEntregaRepository.avanzarSiEstadoPermitido(eq(1L), anyCollection(), eq(EstadoEntrega.ENTREGADO)))
                .thenReturn(1);
        when(datosEntregaRepository.findBySolicitudId(viaje.getSolicitud().getId())).thenReturn(Optional.of(datos));
        entregaService.entregarConReceptor(500L, new IdentificarReceptorRequest("Juan", "7222-3333", -11.03, -68.74), foto());

        verify(viajeService).finalizarDesdeEntrega(eq(500L), any());
    }

    /** Lo que el registro necesita: los productos del pedido, el pedido releido y la propuesta guardada. */
    private void prepararRegistro(Viaje viaje) {
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(productoRepository.findByDatosEntregaIdAndEstadoProductoEntregaOrderByOrdenAscIdAsc(1L, EstadoRegistro.A))
                .thenReturn(List.of(pan, leche));
        enMano = compraEnMano(viaje);
        when(datosEntregaRepository.findBySolicitudId(90L)).thenReturn(Optional.of(enMano));
        when(datosEntregaRepository.getReferenceById(1L)).thenReturn(enMano);
        when(propuestaRepository.save(any(PropuestaCostoEntrega.class))).thenAnswer(i -> i.getArgument(0));
    }

    private PropuestaCostoEntrega propuestaGuardada() {
        ArgumentCaptor<PropuestaCostoEntrega> guardada = ArgumentCaptor.forClass(PropuestaCostoEntrega.class);
        verify(propuestaRepository).save(guardada.capture());
        return guardada.getValue();
    }

    private static RegistrarCompraRequest compra(ProductoCompradoRequest... productos) {
        return new RegistrarCompraRequest(WKT_COMERCIO, "Tienda Central", null, List.of(productos));
    }

    private static ProductoEntrega producto(Long id, String nombre, int cantidad) {
        ProductoEntrega producto = new ProductoEntrega();
        producto.setId(id);
        producto.setNombre(nombre);
        producto.setCantidad(cantidad);
        return producto;
    }

    private static PropuestaCostoEntrega propuesta(Long id, int version, SituacionPropuestaCosto situacion) {
        PropuestaCostoEntrega propuesta = new PropuestaCostoEntrega();
        propuesta.setId(id);
        propuesta.setVersion(version);
        propuesta.setSituacionPropuesta(situacion);
        propuesta.setTotalProductos(new BigDecimal("10.00"));
        propuesta.setTotal(new BigDecimal("19.80"));
        return propuesta;
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