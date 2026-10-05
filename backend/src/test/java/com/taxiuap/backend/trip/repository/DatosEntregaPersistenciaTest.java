package com.taxiuap.backend.trip.repository;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.RolRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.testsupport.DatosPruebaDelivery;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

@SpringBootTest
@Transactional
class DatosEntregaPersistenciaTest {

    @Autowired private DatosEntregaRepository datosEntregaRepository;
    @Autowired private SolicitudViajeRepository solicitudViajeRepository;
    @Autowired private PersonaRepository personaRepository;
    @Autowired private UsuarioRepository usuarioRepository;
    @Autowired private RolRepository rolRepository;
    @Autowired private PasajeroRepository pasajeroRepository;
    @Autowired private ConductorRepository conductorRepository;
    @Autowired private VehiculoRepository vehiculoRepository;
    @Autowired private TipoVehiculoRepository tipoVehiculoRepository;
    @Autowired private CategoriaServicioRepository categoriaServicioRepository;
    @Autowired private PasswordEncoder passwordEncoder;

    private DatosPruebaDelivery datos;

    @BeforeEach
    void prepararDatos() {
        datos = new DatosPruebaDelivery(personaRepository, usuarioRepository, rolRepository, pasajeroRepository,
                conductorRepository, vehiculoRepository, tipoVehiculoRepository, categoriaServicioRepository,
                solicitudViajeRepository, passwordEncoder);
    }

    @Test
    void persisteLaRelacionUnoAUnoYRecuperaElMapeo() {
        // Se crea una solicitud propia: en una base de desarrollo las solicitudes existentes ya
        // pueden tener datos de entrega, y esta relacion es de uno a uno.
        SolicitudViaje solicitud = datos.crearSolicitud(datos.categoriaDelivery(), datos.crearPasajero(),
                new BigDecimal("17.50"));

        DatosEntrega datos = new DatosEntrega();
        datos.setSolicitud(solicitud);
        datos.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        datos.setDescripcion("Medicamento de prueba");
        datos.setCostoProductoEstimado(new BigDecimal("25.00"));
        datos = datosEntregaRepository.saveAndFlush(datos);

        DatosEntrega recuperado = datosEntregaRepository.findBySolicitudId(solicitud.getId()).orElseThrow();
        assertNotNull(datos.getId());
        assertEquals(datos.getId(), recuperado.getId());
        assertEquals(solicitud.getId(), recuperado.getSolicitud().getId());
        assertEquals(TipoEnvio.COMPRA_Y_ENTREGA, recuperado.getTipoEnvio());

        DatosEntrega duplicado = new DatosEntrega();
        duplicado.setSolicitud(solicitud);
        duplicado.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        duplicado.setDescripcion("Duplicado");
        duplicado.setCostoProductoEstimado(new BigDecimal("10.00"));
        assertThrows(DataIntegrityViolationException.class,
                () -> datosEntregaRepository.saveAndFlush(duplicado));
    }
}
