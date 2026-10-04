package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.communication.service.NotificacionPushService;
import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.trip.repository.DatosEntregaRepository;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.trip.repository.ViajeRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

@SpringBootTest
@Transactional
class OfertaViajeDeliveryPersistenciaTest {

    private static final GeometryFactory GEOMETRIA = new GeometryFactory(new PrecisionModel(), 4326);
    private static final List<SituacionViaje> ESTADOS_FINALES =
            List.of(SituacionViaje.COMPLETADO, SituacionViaje.CANCELADO);

    @Autowired private OfertaViajeService ofertaViajeService;
    @Autowired private ConductorRepository conductorRepository;
    @Autowired private PasajeroRepository pasajeroRepository;
    @Autowired private VehiculoRepository vehiculoRepository;
    @Autowired private CategoriaServicioRepository categoriaServicioRepository;
    @Autowired private SolicitudViajeRepository solicitudViajeRepository;
    @Autowired private DatosEntregaRepository datosEntregaRepository;
    @Autowired private ViajeRepository viajeRepository;

    @MockitoBean private NotificacionPushService notificacionPushService;

    @Test
    void aceptarDeliveryPersisteElViajeConLaMotoYLaTarifaRequerida() {
        Vehiculo motoDelivery = vehiculoRepository.findAll().stream()
                .filter(v -> v.getEstadoVehiculo() == EstadoRegistro.A && v.esMotoDelivery())
                .findFirst()
                .orElseThrow(() -> new AssertionError("El seed debe incluir una moto DELIVERY activa"));
        Conductor conductor = conductorRepository.findById(motoDelivery.getConductor().getId()).orElseThrow();
        assertEquals(SituacionAprobacion.APROBADO, conductor.getSituacionAprobacion());
        liberarViajeActivo(conductor);

        CategoriaServicio delivery = new CategoriaServicio();
        delivery.setNombre("DELIVERY");
        delivery.setTipoVehiculo(motoDelivery.getTipoVehiculo());
        delivery = categoriaServicioRepository.saveAndFlush(delivery);
        motoDelivery.setCategoriaServicio(delivery);
        vehiculoRepository.saveAndFlush(motoDelivery);

        Pasajero pasajero = pasajeroRepository.findAll().stream().findFirst()
                .orElseThrow(() -> new AssertionError("El seed debe incluir un pasajero"));

        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(delivery);
        solicitud.setOrigen(punto(-68.75, -11.02));
        solicitud.setDestino(punto(-68.74, -11.03));
        solicitud.setOrigenDireccion("Origen de prueba");
        solicitud.setDestinoDireccion("Destino de prueba");
        solicitud.setPrecioSugerido(new BigDecimal("17.50"));
        solicitud.setSituacionSolicitud(SituacionSolicitud.PENDIENTE);
        solicitud.setFechaSolicitud(LocalDateTime.now());
        solicitud.setEstadoSolViaje(EstadoRegistro.A);
        solicitud = solicitudViajeRepository.saveAndFlush(solicitud);

        DatosEntrega datos = new DatosEntrega();
        datos.setSolicitud(solicitud);
        datos.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        datos.setDescripcion("Documentos de prueba");
        datos.setCostoProductoEstimado(BigDecimal.ZERO);
        datos.setNombreRemitente("Remitente");
        datos.setTelefonoRemitente("70000000");
        datos.setNombreReceptor("Receptor");
        datos.setTelefonoReceptor("71111111");
        datos.setCodigoRecogida("123456");
        datos.setCodigoEntrega("654321");
        datos.setAceptaPoliticaArticulos(true);
        datos.setEstadoEntrega(EstadoEntrega.PENDIENTE_RECOGIDA);
        solicitud.setDatosEntrega(datosEntregaRepository.saveAndFlush(datos));

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

    private void liberarViajeActivo(Conductor conductor) {
        viajeRepository.findFirstByConductorIdAndSituacionViajeNotIn(conductor.getId(), ESTADOS_FINALES)
                .ifPresent(viaje -> viaje.setSituacionViaje(SituacionViaje.CANCELADO));
    }

    private Point punto(double longitud, double latitud) {
        return GEOMETRIA.createPoint(new Coordinate(longitud, latitud));
    }

    @AfterEach
    void limpiarSeguridad() {
        SecurityContextHolder.clearContext();
    }
}
