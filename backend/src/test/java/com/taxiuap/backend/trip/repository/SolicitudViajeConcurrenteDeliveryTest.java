package com.taxiuap.backend.trip.repository;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigDecimal;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.RolRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.testsupport.DatosPruebaDelivery;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

/**
 * Dos transacciones reales que compiten por la misma solicitud DELIVERY: la fila la serializa
 * PostgreSQL y solo una gana el UPDATE condicional de aceptacion.
 */
@SpringBootTest
class SolicitudViajeConcurrenteDeliveryTest {

    @Autowired private SolicitudViajeRepository solicitudRepository;
    @Autowired private DatosEntregaRepository datosEntregaRepository;
    @Autowired private CategoriaServicioRepository categoriaServicioRepository;
    @Autowired private PersonaRepository personaRepository;
    @Autowired private UsuarioRepository usuarioRepository;
    @Autowired private RolRepository rolRepository;
    @Autowired private PasajeroRepository pasajeroRepository;
    @Autowired private ConductorRepository conductorRepository;
    @Autowired private VehiculoRepository vehiculoRepository;
    @Autowired private TipoVehiculoRepository tipoVehiculoRepository;
    @Autowired private PlatformTransactionManager transactionManager;
    @Autowired private PasswordEncoder passwordEncoder;

    private DatosPruebaDelivery datos;

    @BeforeEach
    void prepararDatos() {
        datos = new DatosPruebaDelivery(personaRepository, usuarioRepository, rolRepository, pasajeroRepository,
                conductorRepository, vehiculoRepository, tipoVehiculoRepository, categoriaServicioRepository,
                solicitudRepository, passwordEncoder);
    }

    @Test
    void dosTransaccionesConcurrentesSoloAceptanUnaSolicitudDelivery() throws Exception {
        TransactionTemplate transaccion = new TransactionTemplate(transactionManager);
        Long idSolicitud = transaccion.execute(status -> crearSolicitudDelivery());
        ExecutorService ejecutor = Executors.newFixedThreadPool(2);
        CountDownLatch preparadas = new CountDownLatch(2);
        CountDownLatch inicio = new CountDownLatch(1);
        try {
            Future<Integer> primera = ejecutor.submit(() -> aceptarEnTransaccion(transaccion,
                    idSolicitud, preparadas, inicio));
            Future<Integer> segunda = ejecutor.submit(() -> aceptarEnTransaccion(transaccion,
                    idSolicitud, preparadas, inicio));

            assertTrue(preparadas.await(10, TimeUnit.SECONDS), "Ambas transacciones deben estar listas para competir");
            inicio.countDown();
            List<Integer> filasAfectadas = List.of(primera.get(30, TimeUnit.SECONDS), segunda.get(30, TimeUnit.SECONDS));

            assertEquals(1, filasAfectadas.stream().filter(filas -> filas == 1).count());
            assertEquals(1, filasAfectadas.stream().filter(filas -> filas == 0).count());
            assertEquals(SituacionSolicitud.ACEPTADA,
                    solicitudRepository.findById(idSolicitud).orElseThrow().getSituacionSolicitud());
        } finally {
            inicio.countDown();
            ejecutor.shutdownNow();
            transaccion.executeWithoutResult(status -> limpiarSolicitud(idSolicitud));
        }
    }

    private int aceptarEnTransaccion(TransactionTemplate transaccion, Long idSolicitud,
            CountDownLatch preparadas, CountDownLatch inicio) {
        Integer filas = transaccion.execute(status -> {
            preparadas.countDown();
            try {
                if (!inicio.await(10, TimeUnit.SECONDS)) {
                    throw new IllegalStateException("No se liberaron las transacciones concurrentes");
                }
            } catch (InterruptedException excepcion) {
                Thread.currentThread().interrupt();
                throw new IllegalStateException("Se interrumpio la prueba concurrente", excepcion);
            }
            return solicitudRepository.aceptarSiDisponible(idSolicitud);
        });
        return filas;
    }

    private Long crearSolicitudDelivery() {
        CategoriaServicio delivery = datos.categoriaDelivery();
        SolicitudViaje solicitud = datos.crearSolicitud(delivery, datos.crearPasajero(),
                new BigDecimal("17.50"));

        DatosEntrega datosEntrega = new DatosEntrega();
        datosEntrega.setSolicitud(solicitud);
        datosEntrega.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        datosEntrega.setDescripcion("Paquete concurrente de prueba");
        datosEntrega.setCostoProductoEstimado(BigDecimal.ZERO);
        datosEntrega.setCodigoRecogida("123456");
        datosEntrega.setCodigoEntrega("654321");
        datosEntrega.setAceptaPoliticaArticulos(true);
        datosEntrega.setEstadoEntrega(EstadoEntrega.PENDIENTE_RECOGIDA);
        datosEntregaRepository.saveAndFlush(datosEntrega);
        return solicitud.getId();
    }

    /**
     * Esta prueba no es @Transactional (necesita transacciones reales y separadas), asi que sus
     * datos quedan en la base: se borran al terminar para no acumular solicitudes ni categorias.
     */
    private void limpiarSolicitud(Long idSolicitud) {
        solicitudRepository.findById(idSolicitud).ifPresent(solicitud -> {
            Integer idCategoria = solicitud.getCategoriaServicio().getId();
            datosEntregaRepository.findBySolicitudId(idSolicitud).ifPresent(datosEntregaRepository::delete);
            solicitudRepository.delete(solicitud);
            solicitudRepository.flush();
            // La categoria se borra al final: la solicitud todavia la referenciaba.
            categoriaServicioRepository.findById(idCategoria).ifPresent(categoriaServicioRepository::delete);
        });
    }
}
