package com.taxiuap.backend.vehicle.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.dto.DatosConductorRequest;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.RolRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.testsupport.DatosPruebaDelivery;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

/**
 * Categoria de servicio de la moto que se registra en el conductor: se acepta DELIVERY, se rechaza
 * una categoria de otro tipo de vehiculo, un id inexistente responde 404 y sin categoria sigue la
 * MOTO estandar aunque el catalogo tenga mas categorias MOTO activas.
 *
 * Corre contra PostgreSQL con los repositorios y el servicio reales porque el comportamiento depende
 * de la consulta derivada (categoria activa, orden por id y exclusion de DELIVERY), que con dobles
 * no se probaria. Todo lo que crea la prueba se deshace con el rollback de la transaccion.
 */
@SpringBootTest
@Transactional
class RegistroMotoConductorCategoriaTest {

    private static final String NOMBRE_DELIVERY = "DELIVERY";

    /** Id que no existe en el catalogo: la peticion debe salir con 404 y no con una categoria cualquiera. */
    private static final int ID_CATEGORIA_INEXISTENTE = 987654;

    @Autowired private RegistroMotoConductorService registroMotoConductorService;
    @Autowired private PersonaRepository personaRepository;
    @Autowired private UsuarioRepository usuarioRepository;
    @Autowired private RolRepository rolRepository;
    @Autowired private PasajeroRepository pasajeroRepository;
    @Autowired private ConductorRepository conductorRepository;
    @Autowired private VehiculoRepository vehiculoRepository;
    @Autowired private TipoVehiculoRepository tipoVehiculoRepository;
    @Autowired private CategoriaServicioRepository categoriaServicioRepository;
    @Autowired private SolicitudViajeRepository solicitudViajeRepository;
    @Autowired private PasswordEncoder passwordEncoder;

    private DatosPruebaDelivery datos;

    @BeforeEach
    void prepararDatos() {
        datos = new DatosPruebaDelivery(personaRepository, usuarioRepository, rolRepository, pasajeroRepository,
                conductorRepository, vehiculoRepository, tipoVehiculoRepository, categoriaServicioRepository,
                solicitudViajeRepository, passwordEncoder);
    }

    @Test
    void aceptaLaCategoriaDeliveryEnLaMotoDelConductor() {
        CategoriaServicio delivery = datos.categoriaDelivery();
        Conductor conductor = datos.crearConductorAprobado();

        registrar(conductor, delivery.getId());

        Vehiculo vehiculo = vehiculoDelConductor(conductor.getId());
        assertEquals(delivery.getId(), vehiculo.getCategoriaServicio().getId());
        assertEquals(NOMBRE_DELIVERY, vehiculo.getCategoriaServicio().getNombre());
        assertTrue(vehiculo.esMotoDelivery());
    }

    @Test
    void rechazaUnaCategoriaDeAutoEnLaMotoDelConductor() {
        // Tipo que no es MOTO: su categoria no puede quedar en la moto del conductor.
        TipoVehiculo tipoDeAuto = tipoVehiculo("CAMIONETA-PRUEBA", "Camioneta de prueba");
        CategoriaServicio categoriaDeAuto = categoria("EJECUTIVO-PRUEBA", tipoDeAuto);
        Conductor conductor = datos.crearConductorAprobado();

        NegocioException error = assertThrows(NegocioException.class,
                () -> registrar(conductor, categoriaDeAuto.getId()));

        assertTrue(error.getMessage().contains("categoria de servicio"));
        assertTrue(vehiculoRepository.findByConductorId(conductor.getId()).isEmpty(),
                "una categoria incompatible no debe dejar el vehiculo a medias");
    }

    @Test
    void idDeCategoriaInexistenteDa404() {
        Conductor conductor = datos.crearConductorAprobado();

        // RecursoNoEncontradoException es la que el manejador global traduce a 404.
        assertThrows(RecursoNoEncontradoException.class, () -> registrar(conductor, ID_CATEGORIA_INEXISTENTE));

        assertTrue(vehiculoRepository.findByConductorId(conductor.getId()).isEmpty());
    }

    @Test
    void sinCategoriaLaMotoQuedaConLaCategoriaEstandar() {
        TipoVehiculo moto = datos.tipoMoto();
        CategoriaServicio esperada = categoriaEstandarEsperada(moto);
        Conductor conductor = datos.crearConductorAprobado();

        registrar(conductor, null);

        Vehiculo vehiculo = vehiculoDelConductor(conductor.getId());
        assertEquals(esperada.getId(), vehiculo.getCategoriaServicio().getId());
        assertNotEquals(NOMBRE_DELIVERY, vehiculo.getCategoriaServicio().getNombre().toUpperCase(Locale.ROOT));
    }

    @Test
    void elDefaultNoCambiaConMasCategoriasMotoActivas() {
        TipoVehiculo moto = datos.tipoMoto();
        // Los ids los asigna la secuencia y no se pueden fijar: se apagan las categorias MOTO
        // estandar sembradas para que solo queden las que crea la prueba y se vea que el registro
        // elige la menor activa que no sea DELIVERY (y no la DELIVERY que tiene id menor).
        List<CategoriaServicio> estandarSembradas = categoriaServicioRepository
                .findByTipoVehiculoIdAndEstadoCategoriaServicio(moto.getId(), EstadoRegistro.A).stream()
                .filter(categoria -> !NOMBRE_DELIVERY.equalsIgnoreCase(categoria.getNombre()))
                .toList();
        estandarSembradas.forEach(categoria -> categoria.setEstadoCategoriaServicio(EstadoRegistro.X));
        categoriaServicioRepository.saveAllAndFlush(estandarSembradas);
        CategoriaServicio delivery = categoria(NOMBRE_DELIVERY, moto);
        CategoriaServicio nuevaEstandar = categoria("MOTO-PRUEBA", moto);
        Conductor conductor = datos.crearConductorAprobado();

        registrar(conductor, null);

        Vehiculo vehiculo = vehiculoDelConductor(conductor.getId());
        assertEquals(nuevaEstandar.getId(), vehiculo.getCategoriaServicio().getId());
        assertNotEquals(delivery.getId(), vehiculo.getCategoriaServicio().getId());
        assertTrue(delivery.getId() < nuevaEstandar.getId(),
                "la DELIVERY tiene id menor: el registro no debe tomarla por defecto");
    }

    private void registrar(Conductor conductor, Integer idCategoriaServicio) {
        registroMotoConductorService.registrar(conductor, datosConductor(idCategoriaServicio), Map.of());
    }

    private Vehiculo vehiculoDelConductor(Long idConductor) {
        return vehiculoRepository.findByConductorId(idConductor).stream().findFirst()
                .orElseThrow(() -> new AssertionError("El registro no guardo el vehiculo"));
    }

    /** Estandar esperada calculada aparte: la MOTO activa de menor id que no sea DELIVERY. */
    private CategoriaServicio categoriaEstandarEsperada(TipoVehiculo moto) {
        return categoriaServicioRepository
                .findByTipoVehiculoIdAndEstadoCategoriaServicio(moto.getId(), EstadoRegistro.A).stream()
                .filter(categoria -> !NOMBRE_DELIVERY.equalsIgnoreCase(categoria.getNombre()))
                .min(Comparator.comparing(CategoriaServicio::getId))
                .orElseThrow(() -> new IllegalStateException("El perfil no sembro una categoria MOTO estandar"));
    }

    private TipoVehiculo tipoVehiculo(String codigo, String nombre) {
        TipoVehiculo tipoVehiculo = new TipoVehiculo();
        tipoVehiculo.setCodigo(codigo);
        tipoVehiculo.setNombre(nombre);
        return tipoVehiculoRepository.saveAndFlush(tipoVehiculo);
    }

    private CategoriaServicio categoria(String nombre, TipoVehiculo tipoVehiculo) {
        CategoriaServicio categoria = new CategoriaServicio();
        categoria.setNombre(nombre);
        categoria.setTipoVehiculo(tipoVehiculo);
        return categoriaServicioRepository.saveAndFlush(categoria);
    }

    private DatosConductorRequest datosConductor(Integer idCategoriaServicio) {
        return new DatosConductorRequest("LIC-" + sufijo(), "M", "PRB-" + sufijo(), "Honda", "CB", "Rojo", 2024,
                idCategoriaServicio, Map.of(), null, null);
    }

    private static String sufijo() {
        return UUID.randomUUID().toString().substring(0, 8);
    }
}