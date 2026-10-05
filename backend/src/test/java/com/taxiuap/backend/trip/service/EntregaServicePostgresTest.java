package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.pricing.entity.BilleteraConductor;
import com.taxiuap.backend.pricing.entity.Pago;
import com.taxiuap.backend.pricing.entity.Tarifa;
import com.taxiuap.backend.pricing.enums.SituacionPago;
import com.taxiuap.backend.pricing.repository.BilleteraConductorRepository;
import com.taxiuap.backend.pricing.repository.PagoRepository;
import com.taxiuap.backend.pricing.repository.TarifaRepository;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.testsupport.DatosPruebaDelivery;
import com.taxiuap.backend.trip.dto.ConfirmarPagoEntregaRequest;
import com.taxiuap.backend.trip.dto.ValidarCodigoEntregaRequest;
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
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.RolRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import org.springframework.security.crypto.password.PasswordEncoder;

@SpringBootTest
class EntregaServicePostgresTest {

    private static final GeometryFactory GEOMETRIA = new GeometryFactory(new PrecisionModel(), 4326);
    private static final String CODIGO_RECOGIDA = "123456";
    private static final String CODIGO_ENTREGA = "654321";

    @Autowired private EntregaService entregaService;
    @Autowired private DatosEntregaRepository datosEntregaRepository;
    @Autowired private ViajeRepository viajeRepository;
    @Autowired private SolicitudViajeRepository solicitudRepository;
    @Autowired private PagoRepository pagoRepository;
    @Autowired private BilleteraConductorRepository billeteraRepository;
    @Autowired private TarifaRepository tarifaRepository;
    @Autowired private CategoriaServicioRepository categoriaRepository;
    @Autowired private VehiculoRepository vehiculoRepository;
    @Autowired private TipoVehiculoRepository tipoVehiculoRepository;
    @Autowired private PersonaRepository personaRepository;
    @Autowired private UsuarioRepository usuarioRepository;
    @Autowired private RolRepository rolRepository;
    @Autowired private PasajeroRepository pasajeroRepository;
    @Autowired private ConductorRepository conductorRepository;
    @Autowired private PasswordEncoder passwordEncoder;
    @Autowired private PlatformTransactionManager transactionManager;

    private DatosPruebaDelivery datos;

    @BeforeEach
    void prepararDatos() {
        datos = new DatosPruebaDelivery(personaRepository, usuarioRepository, rolRepository, pasajeroRepository,
                conductorRepository, vehiculoRepository, tipoVehiculoRepository, categoriaRepository,
                solicitudRepository, passwordEncoder);
    }

    @AfterEach
    void limpiarSeguridad() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void recorridoRealDeEncomiendaPersisteEstadoPagoYViajeEnPostgres() {
        Escenario escenario = crearEscenarioEncomienda();
        autenticar(escenario.viaje().getConductor().getUsuario().getId(), "CONDUCTOR");

        entregaService.validarRecogida(escenario.viaje().getId(),
                new ValidarCodigoEntregaRequest(CODIGO_RECOGIDA));
        entregaService.confirmarPago(escenario.viaje().getId(),
                new ConfirmarPagoEntregaRequest(new BigDecimal("17.50"), null));
        entregaService.entregarConCodigo(escenario.viaje().getId(),
                new ValidarCodigoEntregaRequest(CODIGO_ENTREGA));

        new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
            DatosEntrega persistidos = datosEntregaRepository.findById(escenario.datos().getId()).orElseThrow();
            Viaje viajePersistido = viajeRepository.findById(escenario.viaje().getId()).orElseThrow();
            Pago pagoPersistido = pagoRepository.findByViajeId(escenario.viaje().getId()).orElseThrow();
            assertEquals(EstadoEntrega.ENTREGADO, persistidos.getEstadoEntrega());
            assertEquals(true, persistidos.getPagoConfirmado());
            assertEquals(new BigDecimal("17.50"), persistidos.getMontoPagoRecibido());
            assertEquals(SituacionPago.COMPLETADO, pagoPersistido.getSituacionPago());
            assertEquals(SituacionViaje.COMPLETADO, viajePersistido.getSituacionViaje());
        });
    }

    @Test
    void conductorDistintoNoPuedeValidarRecogida() {
        Escenario escenario = crearEscenarioEncomienda();
        Conductor otro = datos.crearConductorAprobado();
        autenticar(otro.getUsuario().getId(), "CONDUCTOR");

        assertThrows(NegocioException.class, () -> entregaService.validarRecogida(escenario.viaje().getId(),
                new ValidarCodigoEntregaRequest(CODIGO_RECOGIDA)));
    }

    @Test
    void pasajeroDistintoNoPuedeConfirmarCompra() {
        Escenario escenario = crearEscenarioCompra();
        Pasajero otro = datos.crearPasajero();
        autenticar(otro.getUsuario().getId(), "PASAJERO");

        assertThrows(NegocioException.class,
                () -> entregaService.confirmarCompra(escenario.viaje().getId()));
    }

    private Escenario crearEscenarioEncomienda() {
        return new TransactionTemplate(transactionManager).execute(status -> {
            CategoriaServicio categoria = datos.categoriaDelivery();
            Pasajero pasajero = datos.crearPasajero();
            Vehiculo vehiculo = datos.crearMotoDelivery(categoria);
            crearBilletera(vehiculo.getConductor());
            Tarifa tarifa = crearTarifa(categoria);
            SolicitudViaje solicitud = datos.crearSolicitud(categoria, pasajero, new BigDecimal("17.50"));
            DatosEntrega datosEntrega = new DatosEntrega();
            datosEntrega.setSolicitud(solicitud);
            datosEntrega.setTipoEnvio(TipoEnvio.ENCOMIENDA);
            datosEntrega.setDescripcion("Documentos de prueba");
            datosEntrega.setCostoProductoEstimado(BigDecimal.ZERO);
            datosEntrega.setCodigoRecogida(CODIGO_RECOGIDA);
            datosEntrega.setCodigoEntrega(CODIGO_ENTREGA);
            datosEntrega.setAceptaPoliticaArticulos(true);
            datosEntrega.setEstadoEntrega(EstadoEntrega.EN_CAMINO_RECOGIDA);
            datosEntrega = datosEntregaRepository.saveAndFlush(datosEntrega);
            Viaje viaje = crearViaje(solicitud, pasajero, vehiculo, tarifa);
            return new Escenario(viaje, datosEntrega);
        });
    }

    private Escenario crearEscenarioCompra() {
        return new TransactionTemplate(transactionManager).execute(status -> {
            CategoriaServicio categoria = datos.categoriaDelivery();
            Pasajero pasajero = datos.crearPasajero();
            Vehiculo vehiculo = datos.crearMotoDelivery(categoria);
            crearBilletera(vehiculo.getConductor());
            Tarifa tarifa = crearTarifa(categoria);
            SolicitudViaje solicitud = datos.crearSolicitud(categoria, pasajero, new BigDecimal("17.50"));
            DatosEntrega datosEntrega = new DatosEntrega();
            datosEntrega.setSolicitud(solicitud);
            datosEntrega.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
            datosEntrega.setDescripcion("Compra de prueba");
            datosEntrega.setCostoProductoEstimado(new BigDecimal("25.00"));
            datosEntrega.setDetalleCompraPropuesto("Comercio de prueba");
            datosEntrega.setCostoProductoConfirmado(new BigDecimal("25.00"));
            datosEntrega.setAceptaPoliticaArticulos(true);
            datosEntrega.setEstadoEntrega(EstadoEntrega.EN_CAMINO_RECOGIDA);
            datosEntrega = datosEntregaRepository.saveAndFlush(datosEntrega);
            Viaje viaje = crearViaje(solicitud, pasajero, vehiculo, tarifa);
            return new Escenario(viaje, datosEntrega);
        });
    }

    private Viaje crearViaje(SolicitudViaje solicitud, Pasajero pasajero, Vehiculo vehiculo, Tarifa tarifa) {
        Viaje viaje = new Viaje();
        viaje.setSolicitud(solicitud);
        viaje.setPasajero(pasajero);
        viaje.setConductor(vehiculo.getConductor());
        viaje.setVehiculo(vehiculo);
        viaje.setCategoriaServicio(solicitud.getCategoriaServicio());
        viaje.setTarifa(tarifa);
        viaje.setOrigen(solicitud.getOrigen());
        viaje.setDestino(solicitud.getDestino());
        viaje.setPrecioOriginal(new BigDecimal("17.50"));
        viaje.setMontoDescuento(BigDecimal.ZERO.setScale(2));
        viaje.setPrecioFinal(new BigDecimal("17.50"));
        viaje.setSituacionViaje(SituacionViaje.CONFIRMADO);
        viaje.setMetodoPago(com.taxiuap.backend.pricing.enums.MetodoPago.EFECTIVO);
        return viajeRepository.saveAndFlush(viaje);
    }

    private Tarifa crearTarifa(CategoriaServicio categoria) {
        Tarifa tarifa = new Tarifa();
        tarifa.setCategoriaServicio(categoria);
        tarifa.setTarifaBase(BigDecimal.ZERO);
        tarifa.setPrecioKm(BigDecimal.ZERO);
        tarifa.setPrecioMinuto(BigDecimal.ZERO);
        tarifa.setTarifaMinima(BigDecimal.ZERO);
        tarifa.setVigenteDesde(LocalDate.now());
        return tarifaRepository.saveAndFlush(tarifa);
    }

    private void crearBilletera(Conductor conductor) {
        BilleteraConductor billetera = new BilleteraConductor();
        billetera.setConductor(conductor);
        billetera.setSaldo(BigDecimal.ZERO.setScale(2));
        billetera.setDeudaComision(BigDecimal.ZERO.setScale(2));
        billeteraRepository.saveAndFlush(billetera);
    }

    private void autenticar(Long idUsuario, String rol) {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtUser(idUsuario, "prueba", rol), null));
    }

    private Point punto(double longitud, double latitud) {
        return GEOMETRIA.createPoint(new Coordinate(longitud, latitud));
    }

    private record Escenario(Viaje viaje, DatosEntrega datos) {
    }
}
