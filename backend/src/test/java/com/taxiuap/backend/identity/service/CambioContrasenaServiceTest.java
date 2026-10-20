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
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.taxiuap.backend.identity.dto.CambiarContrasenaConCodigoRequest;
import com.taxiuap.backend.identity.dto.CambiarContrasenaRequest;
import com.taxiuap.backend.identity.dto.CodigoContrasenaResponse;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Rol;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;

/**
 * Perfil > Cambiar contrasena: con la actual o con el codigo del correo registrado; al terminar, un solo aviso
 * al correo sin la contrasena. Datos inventados.
 */
class CambioContrasenaServiceTest {

    private final UsuarioRepository usuarios = mock(UsuarioRepository.class);
    private final PasswordEncoder codificador = mock(PasswordEncoder.class);
    private final CuentaUsuarioService cuentas = mock(CuentaUsuarioService.class);
    private final CredencialesCorreoService correos = mock(CredencialesCorreoService.class);
    private final CambioContrasenaService servicio = new CambioContrasenaService(usuarios, codificador, cuentas, correos);
    private final AtomicReference<Instant> ahora = new AtomicReference<>(Instant.parse("2026-10-20T14:00:00Z"));
    private Persona persona;
    private Usuario pasajero;
    private Usuario conductor;

    @BeforeEach
    void preparar() {
        servicio.usarReloj(new Clock() {
            @Override
            public ZoneId getZone() {
                return ZoneId.of("America/La_Paz");
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
        persona.setId(8L);
        persona.setNombres("PRUEBA");
        persona.setCorreo("prueba.dos@correo.test");
        pasajero = cuenta(31L, "PASAJERO");
        conductor = cuenta(32L, "CONDUCTOR");
        when(usuarios.findById(31L)).thenReturn(Optional.of(pasajero));
        when(correos.cuentasDeApp(persona)).thenReturn(List.of(pasajero, conductor));
        // "hash:<contrasena>" hace de BCrypt en la prueba.
        when(cuentas.codificar(anyString())).thenAnswer(i -> "hash:" + i.getArgument(0));
        when(codificador.matches(any(), any())).thenAnswer(i -> ("hash:" + i.getArgument(0)).equals(i.getArgument(1)));
    }

    private Usuario cuenta(Long id, String rolCodigo) {
        Rol rol = new Rol();
        rol.setCodigo(rolCodigo);
        Usuario usuario = new Usuario();
        usuario.setId(id);
        usuario.setPersona(persona);
        usuario.setRol(rol);
        usuario.setEstadoUsuario(EstadoRegistro.A);
        usuario.setPasswordHash("hash:Anterior123");
        return usuario;
    }

    private String codigoEnviado() {
        ArgumentCaptor<String> codigo = ArgumentCaptor.forClass(String.class);
        verify(correos).codigoCambioContrasena(eq(persona), codigo.capture(), eq(15L));
        return codigo.getValue();
    }

    // ---------------------------------------------------------------- con la contrasena actual

    @Test
    void conLaActualCambiaLasDosCuentasYAvisaSinLaContrasena() {
        servicio.verificarActual(31L, "Anterior123");
        servicio.cambiarConActual(31L, new CambiarContrasenaRequest("Anterior123", "Nueva12345", "Nueva12345"));

        assertEquals("hash:Nueva12345", pasajero.getPasswordHash());
        assertEquals("hash:Nueva12345", conductor.getPasswordHash());
        verify(correos).contrasenaActualizada(eq(persona), any(LocalDateTime.class));
    }

    @Test
    void laActualIncorrectaNoDejaAvanzar() {
        NegocioException error = assertThrows(NegocioException.class, () -> servicio.verificarActual(31L, "otra"));

        assertEquals("La contraseña actual no es correcta", error.getMessage());
    }

    @Test
    void cincoErroresSeguidosBloqueanQuinceMinutos() {
        for (int i = 0; i < 4; i++) {
            assertThrows(NegocioException.class, () -> servicio.verificarActual(31L, "otra"));
        }
        NegocioException quinto = assertThrows(NegocioException.class, () -> servicio.verificarActual(31L, "otra"));
        assertTrue(quinto.getMessage().contains("15 min"));

        // Bloqueado: ni la correcta pasa hasta que terminen los 15 minutos.
        assertThrows(NegocioException.class, () -> servicio.verificarActual(31L, "Anterior123"));
        ahora.set(ahora.get().plusSeconds(15 * 60 + 1));
        servicio.verificarActual(31L, "Anterior123");
    }

    @Test
    void laNuevaDebeSerDistintaYCoincidirConLaConfirmacion() {
        assertThrows(NegocioException.class, () -> servicio.cambiarConActual(31L,
                new CambiarContrasenaRequest("Anterior123", "Anterior123", "Anterior123")));
        assertThrows(NegocioException.class, () -> servicio.cambiarConActual(31L,
                new CambiarContrasenaRequest("Anterior123", "Nueva12345", "Nueva99999")));
        verify(correos, never()).contrasenaActualizada(any(), any());
    }

    // ---------------------------------------------------------------- con el codigo del correo

    @Test
    void elCodigoLlegaAlCorreoRegistradoYCambiaLaContrasena() {
        CodigoContrasenaResponse enviado = servicio.enviarCodigo(31L);
        assertEquals("pr***@correo.test", enviado.correo());
        String codigo = codigoEnviado();

        servicio.verificarCodigo(31L, codigo);
        servicio.cambiarConCodigo(31L, new CambiarContrasenaConCodigoRequest(codigo, "Nueva12345", "Nueva12345"));

        assertEquals("hash:Nueva12345", pasajero.getPasswordHash());
        assertEquals("hash:Nueva12345", conductor.getPasswordHash());
        verify(correos).contrasenaActualizada(eq(persona), any(LocalDateTime.class));
        // El codigo se gasto: no sirve otra vez.
        assertThrows(NegocioException.class, () -> servicio.verificarCodigo(31L, codigo));
    }

    @Test
    void elCodigoIncorrectoNoCambiaNadaYAlQuintoHayQuePedirOtro() {
        servicio.enviarCodigo(31L);
        String codigo = codigoEnviado();
        String otro = codigo.equals("000000") ? "111111" : "000000";

        for (int i = 0; i < 4; i++) {
            NegocioException error = assertThrows(NegocioException.class, () -> servicio.verificarCodigo(31L, otro));
            assertEquals("El código no es correcto", error.getMessage());
        }
        NegocioException quinto = assertThrows(NegocioException.class, () -> servicio.verificarCodigo(31L, otro));
        assertEquals("Demasiados intentos. Pide un código nuevo", quinto.getMessage());
        assertThrows(NegocioException.class, () -> servicio.verificarCodigo(31L, codigo));
        assertEquals("hash:Anterior123", pasajero.getPasswordHash());
    }

    @Test
    void elCodigoVenceALosQuinceMinutos() {
        servicio.enviarCodigo(31L);
        String codigo = codigoEnviado();
        ahora.set(ahora.get().plusSeconds(15 * 60 + 1));

        NegocioException error = assertThrows(NegocioException.class, () -> servicio.verificarCodigo(31L, codigo));

        assertEquals("El código venció o no existe. Pide uno nuevo", error.getMessage());
    }

    @Test
    void otroCodigoSoloDespuesDeNoventaSegundos() {
        servicio.enviarCodigo(31L);

        ahora.set(ahora.get().plusSeconds(60));
        assertThrows(NegocioException.class, () -> servicio.enviarCodigo(31L));
        assertTrue(servicio.correo(31L).segundosParaReenviar() > 0);

        ahora.set(ahora.get().plusSeconds(31));
        assertEquals(0, servicio.correo(31L).segundosParaReenviar());
        servicio.enviarCodigo(31L);
    }

    @Test
    void sinCorreoRegistradoSoloQuedaLaContrasenaActual() {
        persona.setCorreo(null);

        CodigoContrasenaResponse correo = servicio.correo(31L);

        assertFalse(correo.puedeRecibirCodigo());
        assertNull(correo.correo());
        assertThrows(NegocioException.class, () -> servicio.enviarCodigo(31L));
        verify(correos, never()).codigoCambioContrasena(any(), anyString(), anyLong());
    }
}
