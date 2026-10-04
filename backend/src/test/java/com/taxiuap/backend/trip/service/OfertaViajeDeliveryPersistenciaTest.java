package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigDecimal;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.communication.service.NotificacionPushService;
import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.RolRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.testsupport.DatosPruebaDelivery;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.trip.repository.DatosEntregaRepository;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.trip.repository.ViajeRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

@SpringBootTest
@Transactional
class OfertaViajeDeliveryPersistenciaTest {

    @Autowired private OfertaViajeService ofertaViajeService;
    @Autowired private ConductorRepository conductorRepository;
    @Autowired private SolicitudViajeRepository solicitudViajeRepository;
    @Autowired private DatosEntregaRepository datosEntregaRepository;
    @Autowired private ViajeRepository viajeRepository;
    @Autowired private PersonaRepository personaRepository;
    @Autowired private UsuarioRepository usuarioRepository;
    @Autowired private RolRepository rolRepository;
    @Autowired private PasajeroRepository pasajeroRepository;
    @Autowired private VehiculoRepository vehiculoRepository;
    @Autowired private TipoVehiculoRepository tipoVehiculoRepository;
    @Autowired private CategoriaServicioRepository categoriaServicioRepository;
    @Autowired private PasswordEncoder passwordEncoder;

    @MockitoBean private NotificacionPushService notificacionPushService;

    private DatosPruebaDelivery datos;

    @BeforeEach
    void prepararDatos() {
        datos = new DatosPruebaDelivery(personaRepository, usuarioRepository, rolRepository, pasajeroRepository,
                conductorRepository, vehiculoRepository, tipoVehiculoRepository, categoriaServicioRepository,
                solicitudViajeRepository, passwordEncoder);
    }

    @Test
    void aceptarDeliveryPersisteElViajeConLaMotoYLaTarifaRequerida() {
        // La categoria se crea despues del arranque a proposito: la tarifa tecnica debe resolverse
        // aunque no haya categoria DELIVERY cuando se sembraron los precios.
        CategoriaServicio delivery = datos.categoriaDelivery();
        Vehiculo motoDelivery = datos.crearMotoDelivery(delivery);
        Conductor conductor = conductorRepository.findById(motoDelivery.getConductor().getId()).orElseThrow();
        assertEquals(SituacionAprobacion.APROBADO, conductor.getSituacionAprobacion());

        SolicitudViaje solicitud = datos.crearSolicitud(delivery, datos.crearPasajero(),
                new BigDecimal("17.50"));

        DatosEntrega datosEntrega = new DatosEntrega();
        datosEntrega.setSolicitud(solicitud);
        datosEntrega.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        datosEntrega.setDescripcion("Documentos de prueba");
        datosEntrega.setCostoProductoEstimado(BigDecimal.ZERO);
        datosEntrega.setNombreRemitente("Remitente");
        datosEntrega.setTelefonoRemitente("70000000");
        datosEntrega.setNombreReceptor("Receptor");
        datosEntrega.setTelefonoReceptor("71111111");
        datosEntrega.setCodigoRecogida("123456");
        datosEntrega.setCodigoEntrega("654321");
        datosEntrega.setAceptaPoliticaArticulos(true);
        datosEntrega.setEstadoEntrega(EstadoEntrega.PENDIENTE_RECOGIDA);
        solicitud.setDatosEntrega(datosEntregaRepository.saveAndFlush(datosEntrega));

        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtUser(conductor.getUsuario().getId(), conductor.getUsuario().getNombreUsuario(), "CONDUCTOR"), null));

        var respuesta = ofertaViajeService.aceptarDirecto(solicitud.getId());

        assertNotNull(respuesta);
        Viaje viajePersistido = viajeRepository.findById(respuesta.idViaje()).orElseThrow();
        assertEquals(SituacionViaje.CONFIRMADO, viajePersistido.getSituacionViaje());
        assertTrue(viajePersistido.getVehiculo().esMotoDelivery());
        assertNotNull(viajePersistido.getTarifa());
        assertNull(viajePersistido.getTarifa().getZona());
        assertEquals(new BigDecimal("4.00"), viajePersistido.getTarifa().getTarifaBase());
        assertEquals(new BigDecimal("17.50"), viajePersistido.getPrecioFinal());
        assertEquals("654321", viajePersistido.getSolicitud().getDatosEntrega().getCodigoEntrega());
        assertNull(respuesta.datosEntrega().codigoRecogida());
        assertNull(respuesta.datosEntrega().codigoEntrega());
    }

    @AfterEach
    void limpiarSeguridad() {
        SecurityContextHolder.clearContext();
    }
}
