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
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryService;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.exception.NegocioException;
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
 * "No se pudo entregar" solo existe cuando el repartidor ya tiene el pedido, exige foto y motivo, y
 * cancela sin republicar: no es una cancelacion temprana que otro repartidor pueda tomar, es un
 * incidente que el administrador resuelve con el reporte. La evidencia se escribe en la misma
 * sentencia que cambia el estado, para que no exista un NO_ENTREGADO sin foto ni motivo.
 */
@ExtendWith(MockitoExtension.class)
class EntregaServiceFallaTest {

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
    }

    @AfterEach
    void limpiarSeguridad() {
        org.springframework.security.core.context.SecurityContextHolder.clearContext();
    }

    @Test
    void laFallaGuardaEvidenciaYCancelaElViaje() {
        Viaje viaje = viajeEnMano(TipoEnvio.COMPRA_Y_ENTREGA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(almacenamientoArchivos.carpetaEntregaConductor(any())).thenReturn("personas/20_x/entrega");
        when(almacenamientoArchivos.guardarConSello(any(), eq("personas/20_x/entrega"), eq("falla_entrega"),
                eq("jpg"))).thenReturn("personas/20_x/entrega/falla_1.jpg");
        when(datosEntregaRepository.registrarFallaSiEstadoPermitido(eq(1L), anyCollection(),
                eq(EstadoEntrega.NO_ENTREGADO), eq("El receptor no estaba"), eq("personas/20_x/entrega/falla_1.jpg")))
                        .thenReturn(1);

        entregaService.noSePudoEntregar(500L, "El receptor no estaba", foto());

        verify(datosEntregaRepository).registrarFallaSiEstadoPermitido(eq(1L), anyCollection(),
                eq(EstadoEntrega.NO_ENTREGADO), eq("El receptor no estaba"), eq("personas/20_x/entrega/falla_1.jpg"));
        verify(viajeService).cancelarFallaEntrega(500L);
    }

    @Test
    void laFallaNoRepublicaElPedido() {
        Viaje viaje = viajeEnMano(TipoEnvio.COMPRA_Y_ENTREGA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(almacenamientoArchivos.carpetaEntregaConductor(any())).thenReturn("personas/20_x/entrega");
        when(almacenamientoArchivos.guardarConSello(any(), anyString(), anyString(), anyString()))
                .thenReturn("personas/20_x/entrega/falla_1.jpg");
        when(datosEntregaRepository.registrarFallaSiEstadoPermitido(anyLong(), anyCollection(), any(), anyString(),
                anyString())).thenReturn(1);

        entregaService.noSePudoEntregar(500L, "El receptor no estaba", foto());

        // La falla se cancela con su propia via, la que no republica.
        verify(viajeService, never()).cancelar(anyLong(), any());
    }

    @Test
    void noSeReportaFallaSiElPedidoTodaviaNoEstaEnMano() {
        Viaje viaje = viajeEnMano(TipoEnvio.ENCOMIENDA);
        viaje.getSolicitud().getDatosEntrega().setEstadoEntrega(EstadoEntrega.EN_CAMINO_RECOGIDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.noSePudoEntregar(500L, "El receptor no estaba", foto()));

        assertEquals(true, error.getMessage().contains("manos"));
        verify(datosEntregaRepository, never()).registrarFallaSiEstadoPermitido(anyLong(), anyCollection(), any(),
                anyString(), anyString());
    }

    @Test
    void laFallaExigeMotivo() {
        Viaje viaje = viajeEnMano(TipoEnvio.ENCOMIENDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.noSePudoEntregar(500L, "  ", foto()));

        assertEquals(true, error.getMessage().contains("motivo"));
        verify(almacenamientoArchivos, never()).guardarConSello(any(), anyString(), anyString(), anyString());
    }

    @Test
    void laFallaExigeFoto() {
        Viaje viaje = viajeEnMano(TipoEnvio.ENCOMIENDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.noSePudoEntregar(500L, "El receptor no estaba", null));

        assertEquals(true, error.getMessage().contains("foto"));
        verify(datosEntregaRepository, never()).registrarFallaSiEstadoPermitido(anyLong(), anyCollection(), any(),
                anyString(), anyString());
    }

    @Test
    void unaFallaRepetidaNoSeRegistraDosVeces() {
        Viaje viaje = viajeEnMano(TipoEnvio.ENCOMIENDA);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
        when(almacenamientoArchivos.carpetaEntregaConductor(any())).thenReturn("personas/20_x/entrega");
        when(almacenamientoArchivos.guardarConSello(any(), anyString(), anyString(), anyString()))
                .thenReturn("personas/20_x/entrega/falla_1.jpg");
        // El pedido ya quedo en NO_ENTREGADO: el UPDATE condicional no actualiza nada.
        when(datosEntregaRepository.registrarFallaSiEstadoPermitido(anyLong(), anyCollection(), any(), anyString(),
                anyString())).thenReturn(0);
        when(datosEntregaRepository.findById(1L)).thenReturn(Optional.of(datosNoEntregado(viaje)));

        NegocioException error = assertThrows(NegocioException.class,
                () -> entregaService.noSePudoEntregar(500L, "El receptor no estaba", foto()));

        assertEquals(true, error.getMessage().contains("Transicion de estado no permitida"));
        verify(viajeService, never()).cancelarFallaEntrega(anyLong());
    }

    private Viaje viajeEnMano(TipoEnvio tipoEnvio) {
        CategoriaServicio delivery = new CategoriaServicio();
        delivery.setId(7);
        delivery.setNombre("DELIVERY");
        delivery.setTipoVehiculo(new TipoVehiculo());

        Persona personaConductor = new Persona();
        personaConductor.setNombres("Repartidor");
        personaConductor.setApellidos("Prueba");
        Usuario usuarioConductor = new Usuario();
        usuarioConductor.setId(20L);
        usuarioConductor.setPersona(personaConductor);
        Conductor conductor = new Conductor();
        conductor.setId(40L);
        conductor.setUsuario(usuarioConductor);

        Pasajero pasajero = new Pasajero();
        pasajero.setId(30L);
        pasajero.setUsuario(usuario(10L, "Pasajera"));

        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setId(90L);
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(delivery);
        solicitud.setOrigen(punto(-68.75, -11.02));
        solicitud.setDestino(punto(-68.74, -11.03));

        DatosEntrega datos = new DatosEntrega();
        datos.setId(1L);
        datos.setSolicitud(solicitud);
        datos.setTipoEnvio(tipoEnvio);
        datos.setDescripcion("Medicamento");
        datos.setCostoProductoEstimado(new BigDecimal("25.00"));
        datos.setCostoProductoReal(new BigDecimal("25.00"));
        datos.setEstadoEntrega(EstadoEntrega.EN_MANO);
        datos.setPuntoCompra(PuntoDesdeWkt.convertir("POINT(-68.745 -11.025)"));
        datos.setCompraConfirmadaPorCliente(true);
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
        viaje.setSituacionViaje(SituacionViaje.EN_CURSO);
        return viaje;
    }

    /** Copia del pedido ya en NO_ENTREGADO: lo que devuelve la base tras una falla previa. */
    private DatosEntrega datosNoEntregado(Viaje viaje) {
        DatosEntrega anterior = viaje.getSolicitud().getDatosEntrega();
        DatosEntrega datos = new DatosEntrega();
        datos.setId(anterior.getId());
        datos.setTipoEnvio(anterior.getTipoEnvio());
        datos.setDescripcion(anterior.getDescripcion());
        datos.setEstadoEntrega(EstadoEntrega.NO_ENTREGADO);
        datos.setMotivoFalla("El receptor no estaba");
        datos.setFotoFallaUrl("personas/20_x/entrega/falla_1.jpg");
        return datos;
    }

    private MultipartFile foto() {
        return new MockMultipartFile("foto", "falla.png", "image/png", imagenPng());
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

    private Usuario usuario(Long id, String nombre) {
        Persona persona = new Persona();
        persona.setNombres(nombre);
        persona.setApellidos("Prueba");
        Usuario usuario = new Usuario();
        usuario.setId(id);
        usuario.setPersona(persona);
        return usuario;
    }

    private Point punto(double longitud, double latitud) {
        return GEOMETRIA.createPoint(new Coordinate(longitud, latitud));
    }
}