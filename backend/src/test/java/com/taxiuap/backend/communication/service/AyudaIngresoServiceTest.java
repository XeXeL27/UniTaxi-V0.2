package com.taxiuap.backend.communication.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import com.taxiuap.backend.communication.dto.AyudaIngresoLoginRequest;
import com.taxiuap.backend.communication.dto.AyudaIngresoResponse;
import com.taxiuap.backend.communication.dto.RespuestaAyudaIngresoRequest;
import com.taxiuap.backend.communication.entity.SolicitudAyudaIngreso;
import com.taxiuap.backend.communication.enums.OrigenAyudaIngreso;
import com.taxiuap.backend.communication.enums.ProblemaIngreso;
import com.taxiuap.backend.communication.enums.SituacionAyudaIngreso;
import com.taxiuap.backend.communication.repository.SolicitudAyudaIngresoRepository;
import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Rol;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.identity.service.AutenticacionService;
import com.taxiuap.backend.identity.service.CredencialesCorreoService;
import com.taxiuap.backend.identity.service.GestionUsuarioService;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;

/** Mensajes al administrador desde el login y lo que el administrador hace con ellos. Datos inventados. */
class AyudaIngresoServiceTest {

    private final SolicitudAyudaIngresoRepository repositorio = mock(SolicitudAyudaIngresoRepository.class);
    private final UsuarioRepository usuarios = mock(UsuarioRepository.class);
    private final CredencialesCorreoService correos = mock(CredencialesCorreoService.class);
    private final AutenticacionService autenticacion = mock(AutenticacionService.class);
    private final GestionUsuarioService gestion = mock(GestionUsuarioService.class);
    private final AyudaIngresoService servicio = new AyudaIngresoService(repositorio, usuarios, correos, autenticacion,
            gestion);
    private final JwtUser admin = new JwtUser(1L, "admin", "ADMIN");
    private Persona persona;
    private Usuario cuenta;

    @BeforeEach
    void preparar() {
        servicio.usarReloj(Clock.fixed(Instant.parse("2026-10-21T12:00:00Z"), ZoneId.of("UTC")));
        persona = new Persona();
        persona.setId(7L);
        persona.setNombres("PRUEBA");
        persona.setApellidos("UNO");
        persona.setCorreo("prueba.uno@correo.test");
        Rol rol = new Rol();
        rol.setCodigo("PASAJERO");
        cuenta = new Usuario();
        cuenta.setId(40L);
        cuenta.setNombreUsuario("prueba.uno");
        cuenta.setRol(rol);
        cuenta.setPersona(persona);
        cuenta.setEstadoUsuario(EstadoRegistro.S);
        when(usuarios.findByPersonaId(7L)).thenReturn(List.of(cuenta));
        when(usuarios.findById(1L)).thenReturn(Optional.of(new Usuario()));
        when(correos.cuentasDeApp(persona)).thenReturn(List.of());
        when(repositorio.findFirstByPersonaIdAndOrigenInAndEstadoSolAyudaIngOrderByFechaDesc(anyLong(), anyCollection(),
                any())).thenReturn(Optional.empty());
        when(repositorio.save(any())).thenAnswer(i -> i.getArgument(0));
    }

    private static AyudaIngresoLoginRequest pedido(List<ProblemaIngreso> problemas, String descripcion) {
        return new AyudaIngresoLoginRequest("prueba.uno", "Clave123*", problemas, descripcion, "70000001");
    }

    private SolicitudAyudaIngreso pendiente() {
        SolicitudAyudaIngreso solicitud = new SolicitudAyudaIngreso();
        solicitud.setId(5L);
        solicitud.setPersona(persona);
        solicitud.setCelular("70000001");
        when(repositorio.findById(5L)).thenReturn(Optional.of(solicitud));
        return solicitud;
    }

    @Test
    void con_la_contrasena_de_la_cuenta_suspendida_queda_como_cuenta_suspendida() {
        when(autenticacion.personaParaAyuda("prueba.uno", "Clave123*"))
                .thenReturn(Optional.of(new AutenticacionService.PersonaAyuda(persona, true)));

        servicio.desdeLogin(pedido(List.of(ProblemaIngreso.CUENTA_SUSPENDIDA, ProblemaIngreso.OLVIDE_CONTRASENA), null),
                "10.0.0.1");

        ArgumentCaptor<SolicitudAyudaIngreso> guardada = ArgumentCaptor.forClass(SolicitudAyudaIngreso.class);
        verify(repositorio).save(guardada.capture());
        assertEquals(OrigenAyudaIngreso.CUENTA_SUSPENDIDA, guardada.getValue().getOrigen());
        assertEquals("CUENTA_SUSPENDIDA,OLVIDE_CONTRASENA", guardada.getValue().getProblemas());
        assertEquals("70000001", guardada.getValue().getCelular());
    }

    @Test
    void con_otro_hay_que_escribir_el_motivo() {
        NegocioException e = assertThrows(NegocioException.class,
                () -> servicio.desdeLogin(pedido(List.of(ProblemaIngreso.OTRO), "corto"), "10.0.0.1"));
        assertTrue(e.getMessage().contains("motivo"));
        verify(repositorio, never()).save(any());
    }

    @Test
    void sin_cuenta_con_esos_datos_no_guarda_nada() {
        when(autenticacion.personaParaAyuda(any(), any())).thenReturn(Optional.empty());
        assertThrows(NegocioException.class,
                () -> servicio.desdeLogin(pedido(List.of(ProblemaIngreso.NO_RECUERDO_USUARIO), null), "10.0.0.1"));
        verify(repositorio, never()).save(any());
    }

    @Test
    void un_segundo_mensaje_desde_el_login_espera_24_horas() {
        when(autenticacion.personaParaAyuda(any(), any()))
                .thenReturn(Optional.of(new AutenticacionService.PersonaAyuda(persona, false)));
        SolicitudAyudaIngreso anterior = new SolicitudAyudaIngreso();
        anterior.setFecha(LocalDateTime.of(2026, 10, 21, 8, 0));
        when(repositorio.findFirstByPersonaIdAndOrigenInAndEstadoSolAyudaIngOrderByFechaDesc(eq(7L), anyCollection(),
                any())).thenReturn(Optional.of(anterior));

        NegocioException e = assertThrows(NegocioException.class,
                () -> servicio.desdeLogin(pedido(List.of(ProblemaIngreso.OLVIDE_CONTRASENA), null), "10.0.0.1"));
        assertTrue(e.getMessage().contains("22/10/2026 a las 08:00"));
    }

    @Test
    void habilitar_activa_la_cuenta_avisa_por_correo_y_cierra_el_caso() {
        SolicitudAyudaIngreso solicitud = pendiente();

        servicio.habilitar(5L, new RespuestaAyudaIngresoRequest("Se verifico por telefono", null), admin);

        verify(gestion).cambiarEstado(40L, EstadoRegistro.A, 1L);
        verify(correos).cuentaHabilitada(persona, "prueba.uno");
        assertEquals(SituacionAyudaIngreso.ATENDIDA, solicitud.getSituacion());
        assertEquals("Cuenta habilitada. Se verifico por telefono", solicitud.getObservacionAdmin());
    }

    @Test
    void mantener_suspendida_exige_el_motivo_y_se_lo_envia() {
        SolicitudAyudaIngreso solicitud = pendiente();
        assertThrows(NegocioException.class,
                () -> servicio.mantenerSuspendida(5L, new RespuestaAyudaIngresoRequest(" ", null), admin));

        AyudaIngresoResponse respuesta = servicio.mantenerSuspendida(5L,
                new RespuestaAyudaIngresoRequest("Reportes de otros pasajeros", null), admin);

        verify(correos).cuentaSigueSuspendida(persona, "Reportes de otros pasajeros");
        verify(gestion, never()).cambiarEstado(anyLong(), any(), anyLong());
        assertEquals(SituacionAyudaIngreso.ATENDIDA, solicitud.getSituacion());
        assertEquals(AyudaIngresoResponse.SUSPENDIDA, respuesta.estadoCuenta());
    }

    @Test
    void el_correo_sin_cerrar_deja_el_caso_pendiente_y_anotado() {
        SolicitudAyudaIngreso solicitud = pendiente();

        servicio.enviarCorreo(5L, new RespuestaAyudaIngresoRequest("Envianos una foto de tu carnet", false), admin);

        verify(correos).respuestaAdministrador(persona, "Envianos una foto de tu carnet");
        assertEquals(SituacionAyudaIngreso.PENDIENTE, solicitud.getSituacion());
        assertEquals("21/10 12:00 Correo enviado: Envianos una foto de tu carnet", solicitud.getObservacionAdmin());
    }

    @Test
    void sin_correo_registrado_no_se_puede_escribir() {
        persona.setCorreo(null);
        pendiente();
        NegocioException e = assertThrows(NegocioException.class,
                () -> servicio.enviarCorreo(5L, new RespuestaAyudaIngresoRequest("Hola, revisamos tu caso", true), admin));
        assertTrue(e.getMessage().contains("70000001"));
    }
}
