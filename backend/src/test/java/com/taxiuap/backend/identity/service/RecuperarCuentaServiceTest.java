package com.taxiuap.backend.identity.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.taxiuap.backend.communication.enums.OrigenAyudaIngreso;
import com.taxiuap.backend.communication.service.AyudaIngresoService;
import com.taxiuap.backend.identity.dto.CambiarContrasenaRecuperacionRequest;
import com.taxiuap.backend.identity.dto.CarnetRegistradoRequest;
import com.taxiuap.backend.identity.dto.CodigoRecuperacionResponse;
import com.taxiuap.backend.identity.dto.CuentaRegistradaResponse;
import com.taxiuap.backend.identity.dto.MensajeAyudaIngresoRequest;
import com.taxiuap.backend.identity.dto.VerificarCodigoRecuperacionRequest;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;

/** Limites de "Recuperar mis credenciales": 3 envios, 90 s por codigo, mensaje solo tras el limite. Datos inventados. */
class RecuperarCuentaServiceTest {

    private final PersonaRepository personas = mock(PersonaRepository.class);
    private final UsuarioRepository usuarios = mock(UsuarioRepository.class);
    private final CredencialesCorreoService correos = mock(CredencialesCorreoService.class);
    private final AyudaIngresoService ayuda = mock(AyudaIngresoService.class);
    private final RecuperarCuentaService servicio = new RecuperarCuentaService(personas, usuarios, correos, ayuda);
    private final AtomicReference<Instant> ahora = new AtomicReference<>(Instant.parse("2026-10-15T12:00:00Z"));
    private final AtomicReference<String> ultimoCodigo = new AtomicReference<>();
    private Persona persona;

    @BeforeEach
    void preparar() {
        servicio.usarReloj(new Clock() {
            @Override
            public ZoneId getZone() {
                return ZoneId.of("UTC");
            }

            @Override
            public Clock withZone(ZoneId zona) {
                return this;
            }

            @Override
            public Instant instant() {
                return ahora.get();
            }
        });
        persona = new Persona();
        persona.setId(7L);
        persona.setCi("1234567");
        persona.setCorreo("prueba.uno@correo.test");
        persona.setEstadoPersona(EstadoRegistro.A);
        Usuario cuenta = new Usuario();
        cuenta.setNombreUsuario("prueba.uno");
        when(personas.findByCiAndEstadoPersona("1234567", EstadoRegistro.A)).thenReturn(List.of(persona));
        when(personas.findById(7L)).thenReturn(Optional.of(persona));
        when(correos.cuentasDeApp(persona)).thenReturn(List.of(cuenta));
        when(ayuda.bloqueadoHasta(any())).thenReturn(Optional.empty());
        org.mockito.Mockito.doAnswer(i -> {
            ultimoCodigo.set(i.getArgument(1));
            return null;
        }).when(correos).codigoRecuperarCuenta(any(), anyString(), anyLong());
    }

    private String recuperacion() {
        CuentaRegistradaResponse cuenta = servicio.porCarnet(
                new CarnetRegistradoRequest("1234567", null, OrigenAyudaIngreso.REGISTRO_PASAJERO), "1.1.1.1");
        assertTrue(cuenta.registrado());
        assertEquals("pr***@correo.test", cuenta.correo());
        return cuenta.recuperacion();
    }

    private void avanzar(Duration tiempo) {
        ahora.set(ahora.get().plus(tiempo));
    }

    @Test
    void unCarnetSinRegistrarNoDaRecuperacion() {
        CuentaRegistradaResponse cuenta = servicio.porCarnet(
                new CarnetRegistradoRequest("7654321", null, OrigenAyudaIngreso.REGISTRO_CONDUCTOR), "1.1.1.1");
        assertFalse(cuenta.registrado());
        assertNull(cuenta.recuperacion());
    }

    @Test
    void tresEnviosConEsperaDe90Segundos() {
        String id = recuperacion();
        CodigoRecuperacionResponse primero = servicio.enviarCodigo(id);
        assertEquals(1, primero.envio());
        assertEquals(90, primero.segundosVigencia());
        assertFalse(primero.puedeMensaje());
        assertThrows(NegocioException.class, () -> servicio.enviarCodigo(id));

        avanzar(Duration.ofSeconds(90));
        assertEquals(2, servicio.enviarCodigo(id).envio());
        avanzar(Duration.ofSeconds(90));
        CodigoRecuperacionResponse tercero = servicio.enviarCodigo(id);
        assertEquals(3, tercero.envio());
        assertTrue(tercero.puedeMensaje());
        assertEquals(RecuperarCuentaService.ESPERA_TRAS_LIMITE.toSeconds(), tercero.segundosReenvio());

        avanzar(Duration.ofMinutes(5));
        assertThrows(NegocioException.class, () -> servicio.enviarCodigo(id));
        avanzar(Duration.ofMinutes(11));
        assertEquals(1, servicio.enviarCodigo(id).envio());
    }

    @Test
    void elCodigoVenceALos90Segundos() {
        String id = recuperacion();
        servicio.enviarCodigo(id);
        String codigo = ultimoCodigo.get();
        avanzar(Duration.ofSeconds(91));
        assertThrows(NegocioException.class,
                () -> servicio.verificarCodigo(new VerificarCodigoRecuperacionRequest(id, codigo)));
    }

    @Test
    void conElCodigoCambiaLaContrasenaYNoAntes() {
        String id = recuperacion();
        servicio.enviarCodigo(id);
        assertThrows(NegocioException.class, () -> servicio.cambiarContrasena(
                new CambiarContrasenaRecuperacionRequest(id, "NuevaClave1", "NuevaClave1")));
        assertThrows(NegocioException.class,
                () -> servicio.verificarCodigo(new VerificarCodigoRecuperacionRequest(id, "000000".equals(ultimoCodigo.get()) ? "111111" : "000000")));

        servicio.verificarCodigo(new VerificarCodigoRecuperacionRequest(id, ultimoCodigo.get()));
        assertThrows(NegocioException.class, () -> servicio.cambiarContrasena(
                new CambiarContrasenaRecuperacionRequest(id, "NuevaClave1", "OtraClave1")));
        assertEquals("prueba.uno", servicio.cambiarContrasena(
                new CambiarContrasenaRecuperacionRequest(id, "NuevaClave1", "NuevaClave1")).nombreUsuario());
        verify(correos).aplicarEnCuentasDeApp(persona, "NuevaClave1", false);
        verify(correos).contrasenaRecuperada(persona, "prueba.uno");
        // La recuperacion termino: el identificador ya no sirve.
        assertThrows(NegocioException.class, () -> servicio.enviarCodigo(id));
    }

    @Test
    void elMensajeAlAdministradorSoloDespuesDeLosTresCodigos() {
        String id = recuperacion();
        MensajeAyudaIngresoRequest mensaje = new MensajeAyudaIngresoRequest(id, "No me llega el codigo al correo", "71234567");
        assertThrows(NegocioException.class, () -> servicio.enviarMensaje(mensaje, "1.1.1.1"));
        verify(ayuda, never()).registrar(any(), any(), any(), any(), any(), any());

        for (int i = 0; i < RecuperarCuentaService.ENVIOS_MAXIMOS; i++) {
            servicio.enviarCodigo(id);
            avanzar(Duration.ofSeconds(90));
        }
        servicio.enviarMensaje(mensaje, "1.1.1.1");
        verify(ayuda).registrar(eq(persona), eq(OrigenAyudaIngreso.REGISTRO_PASAJERO), eq(null), eq("71234567"),
                eq("No me llega el codigo al correo"), eq("1.1.1.1"));
    }

    @Test
    void sinCorreoVaDirectoAlMensaje() {
        persona.setCorreo(null);
        String id = servicio.porCarnet(new CarnetRegistradoRequest("1234567", null, OrigenAyudaIngreso.REGISTRO_PASAJERO),
                "1.1.1.1").recuperacion();
        assertThrows(NegocioException.class, () -> servicio.enviarCodigo(id));
        servicio.enviarMensaje(new MensajeAyudaIngresoRequest(id, "Mi correo ya no existe", "61234567"), "1.1.1.1");
        verify(ayuda).registrar(any(), any(), any(), eq("61234567"), any(), any());
    }

    @Test
    void conLaCuentaSuspendidaSoloQuedaElMensaje() {
        Usuario suspendida = new Usuario();
        suspendida.setEstadoUsuario(EstadoRegistro.S);
        com.taxiuap.backend.identity.entity.Rol rol = new com.taxiuap.backend.identity.entity.Rol();
        rol.setCodigo("PASAJERO");
        suspendida.setRol(rol);
        when(correos.cuentasDeApp(persona)).thenReturn(List.of());
        when(usuarios.findByPersonaId(7L)).thenReturn(List.of(suspendida));
        CuentaRegistradaResponse cuenta = servicio.porCarnet(
                new CarnetRegistradoRequest("1234567", null, OrigenAyudaIngreso.REGISTRO_PASAJERO), "1.1.1.1");
        assertFalse(cuenta.puedeRecibirCodigo());
        assertTrue(cuenta.sinCodigo().contains("suspendida"));
        assertThrows(NegocioException.class, () -> servicio.enviarCodigo(cuenta.recuperacion()));
    }

    @Test
    void conUnMensajeRecienteEsperaUnDia() {
        String id = recuperacion();
        when(ayuda.bloqueadoHasta(persona)).thenReturn(Optional.of(LocalDateTime.of(2026, 10, 16, 12, 0)));
        NegocioException error = assertThrows(NegocioException.class, () -> servicio.enviarCodigo(id));
        assertTrue(error.getMessage().contains("16/10"));
    }
}
