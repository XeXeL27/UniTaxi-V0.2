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
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

/**
 * El codigo de recogida y el de entrega se comparan contra la fila, no contra lo que Java leyo antes.
 * Estas pruebas lo demuestran contra PostgreSQL de verdad: dos transacciones que validan el mismo
 * codigo al mismo tiempo, y solo una puede ganar. Si el codigo se comparara en Java, las dos pasarian.
 */
@SpringBootTest
class DatosEntregaTransicionConcurrenteTest {

    private static final List<EstadoEntrega> ANTES_DE_MANO =
            List.of(EstadoEntrega.PENDIENTE_RECOGIDA, EstadoEntrega.EN_CAMINO_RECOGIDA);

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
    void dosValidacionesConcurrentesDelCodigoDeRecogidaSoloHacenUnaTransicion() throws Exception {
        Long idSolicitud = crearEncomienda(EstadoEntrega.EN_CAMINO_RECOGIDA);
        try {
            List<Integer> filas = competir(idSolicitud, (id, espera) ->
                    datosEntregaRepository.avanzarSiCodigoRecogidaCoincide(id, ANTES_DE_MANO,
                            EstadoEntrega.EN_MANO, "123456"), 2);

            assertEquals(1, filas.stream().filter(actualizadas -> actualizadas == 1).count());
            assertEquals(1, filas.stream().filter(actualizadas -> actualizadas == 0).count());
            assertEquals(EstadoEntrega.EN_MANO,
                    datosEntregaRepository.findBySolicitudId(idSolicitud).orElseThrow().getEstadoEntrega());
        } finally {
            limpiar(idSolicitud);
        }
    }

    @Test
    void unCodigoDeRecogidaIncorrectoNoCambiaNadaAunqueSeRepita() {
        Long idSolicitud = crearEncomienda(EstadoEntrega.EN_CAMINO_RECOGIDA);
        try {
            enTransaccion(() -> {
                int filas = datosEntregaRepository.avanzarSiCodigoRecogidaCoincide(
                        datosEntregaRepository.findBySolicitudId(idSolicitud).orElseThrow().getId(),
                        ANTES_DE_MANO, EstadoEntrega.EN_MANO, "000000");

                assertEquals(0, filas);
                assertEquals(EstadoEntrega.EN_CAMINO_RECOGIDA,
                        datosEntregaRepository.findBySolicitudId(idSolicitud).orElseThrow().getEstadoEntrega());
            });
        } finally {
            limpiar(idSolicitud);
        }
    }

    @Test
    void dosEntregasConcurrentesSoloCobranUnaComision() throws Exception {
        Long idSolicitud = crearEncomienda(EstadoEntrega.EN_MANO);
        try {
            enTransaccion(() -> datosEntregaRepository.findBySolicitudId(idSolicitud).ifPresent(datosEntrega -> {
                datosEntrega.setPagoConfirmado(true);
                datosEntrega.setMontoPagoRecibido(new BigDecimal("17.50"));
                datosEntregaRepository.saveAndFlush(datosEntrega);
            }));

            List<Integer> filas = competir(idSolicitud, (id, espera) ->
                    datosEntregaRepository.avanzarSiCodigoEntregaCoincide(id, List.of(EstadoEntrega.EN_MANO),
                            EstadoEntrega.ENTREGADO, "654321"), 2);

            assertEquals(1, filas.stream().filter(actualizadas -> actualizadas == 1).count());
            assertEquals(1, filas.stream().filter(actualizadas -> actualizadas == 0).count());
            assertEquals(EstadoEntrega.ENTREGADO,
                    datosEntregaRepository.findBySolicitudId(idSolicitud).orElseThrow().getEstadoEntrega());
        } finally {
            limpiar(idSolicitud);
        }
    }

    @Test
    void unaFallaRepetidaNoSobrescribeLaEvidenciaDeLaPrimera() {
        Long idSolicitud = crearEncomienda(EstadoEntrega.EN_MANO);
        try {
            enTransaccion(() -> {
                Long idDatos = datosEntregaRepository.findBySolicitudId(idSolicitud).orElseThrow().getId();
                int primera = datosEntregaRepository.registrarFallaSiEstadoPermitido(idDatos,
                        List.of(EstadoEntrega.EN_MANO), EstadoEntrega.NO_ENTREGADO, "El receptor no estaba",
                        "falla_1.jpg");
                int segunda = datosEntregaRepository.registrarFallaSiEstadoPermitido(idDatos,
                        List.of(EstadoEntrega.EN_MANO), EstadoEntrega.NO_ENTREGADO, "Se rindio", "falla_2.jpg");

                assertEquals(1, primera);
                assertEquals(0, segunda);
                DatosEntrega guardado = datosEntregaRepository.findBySolicitudId(idSolicitud).orElseThrow();
                assertEquals("El receptor no estaba", guardado.getMotivoFalla());
                assertEquals("falla_1.jpg", guardado.getFotoFallaUrl());
            });
        } finally {
            limpiar(idSolicitud);
        }
    }

    @Test
    void unPedidoYaEntregadoNoAceptaUnaFalla() {
        Long idSolicitud = crearEncomienda(EstadoEntrega.EN_MANO);
        try {
            enTransaccion(() -> {
                Long idDatos = datosEntregaRepository.findBySolicitudId(idSolicitud).orElseThrow().getId();
                datosEntregaRepository.avanzarSiEstadoPermitido(idDatos, List.of(EstadoEntrega.EN_MANO),
                        EstadoEntrega.ENTREGADO);

                int filas = datosEntregaRepository.registrarFallaSiEstadoPermitido(idDatos,
                        List.of(EstadoEntrega.EN_MANO), EstadoEntrega.NO_ENTREGADO, "Tarde", "falla_1.jpg");

                assertEquals(0, filas);
                assertEquals(EstadoEntrega.ENTREGADO,
                        datosEntregaRepository.findBySolicitudId(idSolicitud).orElseThrow().getEstadoEntrega());
            });
        } finally {
            limpiar(idSolicitud);
        }
    }

    private List<Integer> competir(Long idSolicitud, Transicion transicion, int cuantos) throws Exception {
        TransactionTemplate transaccion = new TransactionTemplate(transactionManager);
        Long idDatos = datosEntregaRepository.findBySolicitudId(idSolicitud).orElseThrow().getId();
        ExecutorService ejecutor = Executors.newFixedThreadPool(cuantos);
        CountDownLatch preparadas = new CountDownLatch(cuantos);
        CountDownLatch inicio = new CountDownLatch(1);
        try {
            List<Future<Integer>> resultados = new java.util.ArrayList<>();
            for (int i = 0; i < cuantos; i++) {
                resultados.add(ejecutor.submit(() -> enTransaccion(transaccion, idDatos, transicion, preparadas,
                        inicio)));
            }
            assertTrue(preparadas.await(10, TimeUnit.SECONDS), "Las transacciones deben estar listas");
            inicio.countDown();
            List<Integer> filas = new java.util.ArrayList<>();
            for (Future<Integer> resultado : resultados) {
                filas.add(resultado.get(30, TimeUnit.SECONDS));
            }
            return filas;
        } finally {
            inicio.countDown();
            ejecutor.shutdownNow();
        }
    }

    /** Los UPDATE condicionales necesitan una transaccion real: esta prueba no es @Transactional. */
    private void enTransaccion(Runnable accion) {
        new TransactionTemplate(transactionManager).executeWithoutResult(status -> accion.run());
    }

    private interface Transicion {
        int aplicar(Long idDatos, CountDownLatch espera);
    }

    private Integer enTransaccion(TransactionTemplate transaccion, Long idDatos, Transicion transicion,
            CountDownLatch preparadas, CountDownLatch inicio) {
        return transaccion.execute(status -> {
            preparadas.countDown();
            try {
                if (!inicio.await(10, TimeUnit.SECONDS)) {
                    throw new IllegalStateException("No se liberaron las transacciones concurrentes");
                }
            } catch (InterruptedException excepcion) {
                Thread.currentThread().interrupt();
                throw new IllegalStateException("Se interrumpio la prueba concurrente", excepcion);
            }
            return transicion.aplicar(idDatos, inicio);
        });
    }

    private Long crearEncomienda(EstadoEntrega estadoEntrega) {
        TransactionTemplate transaccion = new TransactionTemplate(transactionManager);
        return transaccion.execute(status -> {
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
            datosEntrega.setEstadoEntrega(estadoEntrega);
            datosEntregaRepository.saveAndFlush(datosEntrega);
            return solicitud.getId();
        });
    }

    /**
     * Esta prueba no es @Transactional (necesita transacciones reales y separadas), asi que sus datos
     * quedan en la base: se borran al terminar para no acumular solicitudes ni categorias.
     */
    private void limpiar(Long idSolicitud) {
        TransactionTemplate transaccion = new TransactionTemplate(transactionManager);
        transaccion.executeWithoutResult(status -> solicitudRepository.findById(idSolicitud).ifPresent(solicitud -> {
            Integer idCategoria = solicitud.getCategoriaServicio().getId();
            datosEntregaRepository.findBySolicitudId(idSolicitud).ifPresent(datosEntregaRepository::delete);
            solicitudRepository.delete(solicitud);
            solicitudRepository.flush();
            categoriaServicioRepository.findById(idCategoria).ifPresent(categoriaServicioRepository::delete);
        }));
    }
}