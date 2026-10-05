package com.taxiuap.backend.controller.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.RolRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.testsupport.DatosPruebaDelivery;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

/**
 * El administrador corrige la categoria de servicio de la moto de un conductor desde el panel.
 *
 * La regla ADMIN la aplica la cadena JWT, asi que se prueba por HTTP con MockMvc y no con dobles:
 * un doble del servicio no distinguiria un 403 de un 200. Lo que si depende de la base (que el
 * cambio quede guardado, que un vehiculo de otro conductor de 404, que dos vehiculos activos de
 * 422) se comprueba con los repositorios reales. Todo lo que crea la prueba se deshace con el
 * rollback de la transaccion.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class ConductorAdminVehiculoCategoriaTest {

    /** Id que no existe en el catalogo de categorias. */
    private static final int ID_CATEGORIA_INEXISTENTE = 987654;

    @Autowired private MockMvc mockMvc;
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
    void sinTokenResponde401() throws Exception {
        Conductor conductor = conductorConMoto(categoriaMoto("MOTO-PRUEBA"));

        mockMvc.perform(cambiar(conductor, categoriaMoto("OTRA-MOTO-PRUEBA").getId()))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void pasajeroNoPuedeCambiarLaCategoria() throws Exception {
        Conductor conductor = conductorConMoto(categoriaMoto("MOTO-PRUEBA"));
        Vehiculo moto = vehiculoActivo(conductor);

        mockMvc.perform(cambiar(conductor, categoriaMoto("OTRA-MOTO-PRUEBA").getId())
                .with(user("pasajero").roles("PASAJERO")))
                .andExpect(status().isForbidden());

        assertEquals("MOTO-PRUEBA", categoriaDe(moto));
    }

    @Test
    void conductorNoPuedeCambiarLaCategoria() throws Exception {
        Conductor conductor = conductorConMoto(categoriaMoto("MOTO-PRUEBA"));
        Vehiculo moto = vehiculoActivo(conductor);

        mockMvc.perform(cambiar(conductor, categoriaMoto("OTRA-MOTO-PRUEBA").getId())
                .with(user("conductor").roles("CONDUCTOR")))
                .andExpect(status().isForbidden());

        assertEquals("MOTO-PRUEBA", categoriaDe(moto));
    }

    /**
     * Sin idVehiculo el cambio cae sobre el unico vehiculo activo del conductor y queda guardado:
     * se comprueba en la base y despues con el listado que ya consume el panel.
     */
    @Test
    void adminCambiaLaCategoriaDelUnicoVehiculoActivo() throws Exception {
        Conductor conductor = conductorConMoto(categoriaMoto("MOTO-PRUEBA"));
        Vehiculo moto = vehiculoActivo(conductor);
        CategoriaServicio delivery = datos.categoriaDelivery();

        mockMvc.perform(cambiar(conductor, delivery.getId()).with(user("admin").roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ok").value(true))
                .andExpect(jsonPath("$.datos.id").value(moto.getId()))
                .andExpect(jsonPath("$.datos.idCategoriaServicio").value(delivery.getId()))
                .andExpect(jsonPath("$.datos.nombreCategoriaServicio").value("DELIVERY"));

        assertEquals(delivery.getId(), vehiculoRepository.findById(moto.getId()).orElseThrow()
                .getCategoriaServicio().getId());

        mockMvc.perform(get("/api/admin/conductores/{id}/vehiculos", conductor.getId())
                .with(user("admin").roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.datos[0].id").value(moto.getId()))
                .andExpect(jsonPath("$.datos[0].nombreCategoriaServicio").value("DELIVERY"));
    }

    /** Con idVehiculo se cambia ese vehiculo aunque el conductor tenga mas de uno. */
    @Test
    void adminCambiaLaCategoriaDelVehiculoIndicado() throws Exception {
        Conductor conductor = conductorConMoto(categoriaMoto("MOTO-PRUEBA"));
        Vehiculo segundo = moto(conductor, categoriaMoto("SEGUNDA-MOTO-PRUEBA"));
        CategoriaServicio delivery = datos.categoriaDelivery();

        mockMvc.perform(cambiar(conductor, delivery.getId(), segundo.getId()).with(user("admin").roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.datos.id").value(segundo.getId()));

        assertEquals(delivery.getId(), vehiculoRepository.findById(segundo.getId()).orElseThrow()
                .getCategoriaServicio().getId());
    }

    @Test
    void categoriaInvalidaDa404() throws Exception {
        Conductor conductor = conductorConMoto(categoriaMoto("MOTO-PRUEBA"));

        mockMvc.perform(cambiar(conductor, ID_CATEGORIA_INEXISTENTE).with(user("admin").roles("ADMIN")))
                .andExpect(status().isNotFound());
    }

    /** Sin idCategoriaServicio el cuerpo es invalido: 400 antes de tocar el vehiculo. */
    @Test
    void sinIdCategoriaDa400() throws Exception {
        Conductor conductor = conductorConMoto(categoriaMoto("MOTO-PRUEBA"));
        Vehiculo moto = vehiculoActivo(conductor);

        mockMvc.perform(put("/api/admin/conductores/{id}/vehiculo/categoria", conductor.getId())
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}")
                .with(user("admin").roles("ADMIN")))
                .andExpect(status().isBadRequest());

        assertEquals("MOTO-PRUEBA", categoriaDe(moto));
    }

    /** El vehiculo de otro conductor no existe para esta peticion: 404 y ningun cambio ajeno. */
    @Test
    void vehiculoDeOtroConductorDa404() throws Exception {
        Conductor conductor = conductorConMoto(categoriaMoto("MOTO-PRUEBA"));
        Vehiculo propio = vehiculoActivo(conductor);
        Vehiculo ajeno = moto(datos.crearConductorAprobado(), categoriaMoto("MOTO-PRUEBA"));

        mockMvc.perform(cambiar(conductor, datos.categoriaDelivery().getId(), ajeno.getId())
                .with(user("admin").roles("ADMIN")))
                .andExpect(status().isNotFound());

        assertEquals("MOTO-PRUEBA", vehiculoRepository.findById(propio.getId()).orElseThrow()
                .getCategoriaServicio().getNombre());
        assertEquals("MOTO-PRUEBA", vehiculoRepository.findById(ajeno.getId()).orElseThrow()
                .getCategoriaServicio().getNombre());
    }

    /** Con dos vehiculos activos el endpoint no elige por su cuenta: 422 y que se indique cual. */
    @Test
    void dosVehiculosActivosSinIdVehiculoDa422() throws Exception {
        Conductor conductor = conductorConMoto(categoriaMoto("MOTO-PRUEBA"));
        moto(conductor, categoriaMoto("SEGUNDA-MOTO-PRUEBA"));

        mockMvc.perform(cambiar(conductor, datos.categoriaDelivery().getId()).with(user("admin").roles("ADMIN")))
                .andExpect(status().isUnprocessableContent());
    }

    /** Los vehiculos eliminados no cuentan: el que quedo activo es el unico al que se le cambia. */
    @Test
    void elVehiculoEliminadoNoCuentaParaElegir() throws Exception {
        Conductor conductor = conductorConMoto(categoriaMoto("MOTO-PRUEBA"));
        Vehiculo eliminado = moto(conductor, categoriaMoto("ELIMINADA-PRUEBA"));
        eliminado.setEstadoVehiculo(EstadoRegistro.X);
        vehiculoRepository.saveAndFlush(eliminado);
        Vehiculo activo = vehiculoActivo(conductor);
        CategoriaServicio delivery = datos.categoriaDelivery();

        mockMvc.perform(cambiar(conductor, delivery.getId()).with(user("admin").roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.datos.id").value(activo.getId()))
                .andExpect(jsonPath("$.datos.idCategoriaServicio").value(delivery.getId()));
    }

    // ------------------------------------------------------------------ ayudas

    private MockHttpServletRequestBuilder cambiar(Conductor conductor, Integer idCategoriaServicio) {
        return cambiar(conductor, idCategoriaServicio, null);
    }

    /** [idVehiculo] es un int en el request, asi que se convierte el id bigint de la entidad. */
    private MockHttpServletRequestBuilder cambiar(Conductor conductor, Integer idCategoriaServicio,
            Long idVehiculo) {
        return put("/api/admin/conductores/{id}/vehiculo/categoria", conductor.getId())
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"idCategoriaServicio\":" + idCategoriaServicio
                        + (idVehiculo == null ? "" : ",\"idVehiculo\":" + Math.toIntExact(idVehiculo)) + "}");
    }

    private Conductor conductorConMoto(CategoriaServicio categoria) {
        return moto(datos.crearConductorAprobado(), categoria).getConductor();
    }

    private Vehiculo moto(Conductor conductor, CategoriaServicio categoria) {
        Vehiculo moto = new Vehiculo();
        moto.setConductor(conductor);
        moto.setTipoVehiculo(datos.tipoMoto());
        moto.setCategoriaServicio(categoria);
        moto.setPlaca("PRB-" + UUID.randomUUID().toString().substring(0, 8));
        moto.setMarca("Prueba");
        moto.setAnio(2024);
        return vehiculoRepository.saveAndFlush(moto);
    }

    private Vehiculo vehiculoActivo(Conductor conductor) {
        return vehiculoRepository.findByConductorId(conductor.getId()).stream()
                .filter(vehiculo -> vehiculo.getEstadoVehiculo() == EstadoRegistro.A)
                .findFirst()
                .orElseThrow(() -> new AssertionError("El conductor no tiene vehiculo activo"));
    }

    /** Nombre de la categoria del vehiculo segun lo que quedo guardado, no segun el contexto. */
    private String categoriaDe(Vehiculo vehiculo) {
        return vehiculoRepository.findById(vehiculo.getId()).orElseThrow()
                .getCategoriaServicio().getNombre();
    }

    private CategoriaServicio categoriaMoto(String nombre) {
        CategoriaServicio categoria = new CategoriaServicio();
        categoria.setNombre(nombre);
        categoria.setTipoVehiculo(datos.tipoMoto());
        return categoriaServicioRepository.saveAndFlush(categoria);
    }
}