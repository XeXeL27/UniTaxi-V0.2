package com.taxiuap.backend.identity.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.CambiarTiposUsuarioRequest;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Rol;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.TipoRegistroUsuario;
import com.taxiuap.backend.identity.repository.AdministradorRepository;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.trip.repository.ViajeRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;
import com.taxiuap.backend.vehicle.service.RegistroMotoConductorService;
import com.taxiuap.backend.vehicle.service.VehiculoService;

/** Cambio de tipos de usuario desde la ficha del panel y corte de la sesion de la app. Datos inventados. */
class CambioTiposUsuarioTest {

    private final UsuarioRepository usuarios = mock(UsuarioRepository.class);
    private final PasajeroRepository pasajeros = mock(PasajeroRepository.class);
    private final ConductorRepository conductores = mock(ConductorRepository.class);
    private final AdministradorRepository administradores = mock(AdministradorRepository.class);
    private final GestionPersonaService personas = mock(GestionPersonaService.class);
    private final CuentaUsuarioService cuentas = mock(CuentaUsuarioService.class);
    private final RegistroMotoConductorService motos = mock(RegistroMotoConductorService.class);
    private final VehiculoRepository vehiculos = mock(VehiculoRepository.class);
    private final VehiculoService vehiculoService = mock(VehiculoService.class);
    private final GestionUsuarioService servicio = new GestionUsuarioService(usuarios, pasajeros, conductores,
            administradores, personas, cuentas, motos, mock(ViajeRepository.class),
            mock(SolicitudViajeRepository.class), vehiculos, vehiculoService);

    private final Persona persona = new Persona();
    private final List<Usuario> deLaPersona = new ArrayList<>();
    private Usuario pasajero;
    private Usuario conductor;
    private Conductor perfilConductor;
    private Vehiculo moto;

    @BeforeEach
    void preparar() {
        persona.setId(60L);
        when(personas.buscarActiva(60L)).thenReturn(persona);
        when(usuarios.findByPersonaId(60L)).thenReturn(deLaPersona);
        when(usuarios.findById(anyLong())).thenAnswer(i -> deLaPersona.stream()
                .filter(u -> u.getId().equals(i.getArgument(0))).findFirst());

        pasajero = cuenta(81L, RolSistema.PASAJERO);
        conductor = cuenta(82L, RolSistema.CONDUCTOR);
        Pasajero perfilPasajero = new Pasajero();
        when(pasajeros.findByUsuarioId(81L)).thenReturn(Optional.of(perfilPasajero));
        perfilConductor = new Conductor();
        perfilConductor.setId(15L);
        when(conductores.findByUsuarioId(82L)).thenReturn(Optional.of(perfilConductor));
        moto = new Vehiculo();
        TipoVehiculo tipo = new TipoVehiculo();
        tipo.setCodigo("MOTO");
        moto.setTipoVehiculo(tipo);
        moto.setCategoriaServicio(categoria("ESTANDAR", tipo));
        when(vehiculos.findByConductorIdInAndEstadoVehiculoOrderByIdAsc(List.of(15L), EstadoRegistro.A))
                .thenReturn(List.of(moto));
        when(motos.idCategoriaDelivery()).thenReturn(4);
        when(motos.idCategoriaEstandar()).thenReturn(1);
    }

    private Usuario cuenta(Long id, RolSistema rolSistema) {
        Rol rol = new Rol();
        rol.setCodigo(rolSistema.getCodigo());
        Usuario usuario = new Usuario();
        usuario.setId(id);
        usuario.setRol(rol);
        usuario.setPersona(persona);
        usuario.setNombreUsuario("prueba.tres");
        deLaPersona.add(usuario);
        return usuario;
    }

    private static CategoriaServicio categoria(String nombre, TipoVehiculo tipo) {
        CategoriaServicio categoria = new CategoriaServicio();
        categoria.setNombre(nombre);
        categoria.setTipoVehiculo(tipo);
        return categoria;
    }

    private static CambiarTiposUsuarioRequest pedido(BigDecimal limite, TipoRegistroUsuario... tipos) {
        return new CambiarTiposUsuarioRequest(List.of(tipos), limite);
    }

    @Test
    void los_tipos_distinguen_taxi_de_delivery() {
        assertEquals(List.of(TipoRegistroUsuario.PASAJERO, TipoRegistroUsuario.CONDUCTOR), servicio.tiposDe(persona));
        moto.setCategoriaServicio(categoria("DELIVERY", moto.getTipoVehiculo()));
        assertEquals(List.of(TipoRegistroUsuario.PASAJERO, TipoRegistroUsuario.DELIVERY), servicio.tiposDe(persona));
    }

    @Test
    void quitar_pasajero_elimina_su_cuenta_y_corta_la_sesion() {
        servicio.cambiarTipos(60L, pedido(null, TipoRegistroUsuario.CONDUCTOR), 1L);

        assertEquals(EstadoRegistro.X, pasajero.getEstadoUsuario());
        assertEquals(EstadoRegistro.A, conductor.getEstadoUsuario());
        assertNotNull(conductor.getSesionValidaDesde());
    }

    @Test
    void pasar_de_taxi_a_delivery_cambia_la_categoria_y_el_limite() {
        servicio.cambiarTipos(60L, pedido(new BigDecimal("80"), TipoRegistroUsuario.PASAJERO,
                TipoRegistroUsuario.DELIVERY), 1L);

        verify(vehiculoService).cambiarCategoriaServicio(82L, null, 4);
        assertEquals(new BigDecimal("80"), perfilConductor.getLimiteAdelantoCompra());
        assertEquals(EstadoRegistro.A, pasajero.getEstadoUsuario());
        assertNotNull(pasajero.getSesionValidaDesde());
    }

    @Test
    void sin_cambios_no_corta_la_sesion() {
        servicio.cambiarTipos(60L, pedido(null, TipoRegistroUsuario.PASAJERO, TipoRegistroUsuario.CONDUCTOR), 1L);

        verify(vehiculoService, never()).cambiarCategoriaServicio(any(), any(), any());
        assertNull(pasajero.getSesionValidaDesde());
        assertNull(conductor.getSesionValidaDesde());
    }

    @Test
    void agregar_administrador_pide_usar_habilitar_usuario() {
        NegocioException error = assertThrows(NegocioException.class, () -> servicio.cambiarTipos(60L,
                pedido(null, TipoRegistroUsuario.PASAJERO, TipoRegistroUsuario.CONDUCTOR, TipoRegistroUsuario.ADMIN), 1L));
        assertTrue(error.getMessage().contains("Habilitar usuario"));
        assertEquals(EstadoRegistro.A, pasajero.getEstadoUsuario());
    }

    @Test
    void no_se_quitan_todos_ni_taxi_con_delivery() {
        assertThrows(NegocioException.class, () -> servicio.cambiarTipos(60L, pedido(null), 1L));
        assertThrows(NegocioException.class, () -> servicio.cambiarTipos(60L,
                pedido(null, TipoRegistroUsuario.CONDUCTOR, TipoRegistroUsuario.DELIVERY), 1L));
    }

    @Test
    void el_token_emitido_antes_del_corte_ya_no_sirve() {
        LocalDateTime corte = LocalDateTime.now();
        long ms = corte.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli();
        assertTrue(new JwtUser(1L, "prueba", "PASAJERO", ms - 1).emitidoAntesDe(corte));
        assertFalse(new JwtUser(1L, "prueba", "PASAJERO", ms + 1).emitidoAntesDe(corte));
        assertFalse(new JwtUser(1L, "prueba", "PASAJERO", ms - 1).emitidoAntesDe(null));
    }
}
