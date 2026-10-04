package com.taxiuap.backend.trip.repository;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.Test;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;

@SpringBootTest
class SolicitudViajeConcurrenteDeliveryTest {

    private static final GeometryFactory GEOMETRIA = new GeometryFactory(new PrecisionModel(), 4326);

    @Autowired private SolicitudViajeRepository solicitudRepository;
    @Autowired private DatosEntregaRepository datosEntregaRepository;
    @Autowired private PasajeroRepository pasajeroRepository;
    @Autowired private CategoriaServicioRepository categoriaServicioRepository;
    @Autowired private TipoVehiculoRepository tipoVehiculoRepository;
    @Autowired private PlatformTransactionManager transactionManager;

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
            transaccion.executeWithoutResult(status -> {
                datosEntregaRepository.findBySolicitudId(idSolicitud).ifPresent(datosEntregaRepository::delete);
                solicitudRepository.deleteById(idSolicitud);
            });
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
        var pasajero = pasajeroRepository.findAll().stream().findFirst()
                .orElseThrow(() -> new AssertionError("El seed debe incluir un pasajero"));
        var tipoMoto = tipoVehiculoRepository.findAll().stream()
                .filter(tipo -> "MOTO".equalsIgnoreCase(tipo.getCodigo()))
                .findFirst()
                .orElseThrow(() -> new AssertionError("El catalogo debe incluir MOTO"));
        CategoriaServicio delivery = new CategoriaServicio();
        delivery.setTipoVehiculo(tipoMoto);
        delivery.setNombre("DELIVERY");
        delivery = categoriaServicioRepository.saveAndFlush(delivery);

        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(delivery);
        solicitud.setOrigen(punto(-68.75, -11.02));
        solicitud.setDestino(punto(-68.74, -11.03));
        solicitud.setPrecioSugerido(new BigDecimal("17.50"));
        solicitud.setSituacionSolicitud(SituacionSolicitud.PENDIENTE);
        solicitud.setFechaSolicitud(LocalDateTime.now());
        solicitud.setEstadoSolViaje(EstadoRegistro.A);
        solicitud = solicitudRepository.saveAndFlush(solicitud);

        DatosEntrega datos = new DatosEntrega();
        datos.setSolicitud(solicitud);
        datos.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        datos.setDescripcion("Paquete concurrente de prueba");
        datos.setCostoProductoEstimado(BigDecimal.ZERO);
        datos.setCodigoRecogida("123456");
        datos.setCodigoEntrega("654321");
        datos.setAceptaPoliticaArticulos(true);
        datos.setEstadoEntrega(EstadoEntrega.PENDIENTE_RECOGIDA);
        datosEntregaRepository.saveAndFlush(datos);
        return solicitud.getId();
    }

    private Point punto(double longitud, double latitud) {
        return GEOMETRIA.createPoint(new Coordinate(longitud, latitud));
    }
}
