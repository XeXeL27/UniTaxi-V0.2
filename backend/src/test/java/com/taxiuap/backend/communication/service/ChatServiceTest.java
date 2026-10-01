package com.taxiuap.backend.communication.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import com.taxiuap.backend.communication.dto.MensajeEnvioRequest;
import com.taxiuap.backend.communication.dto.MensajeResponse;
import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.service.ViajeService;

@ExtendWith(MockitoExtension.class)
class ChatServiceTest {

    private static final Long ID_VIAJE = 100L;
    private static final Long ID_PASAJERO = 10L;
    private static final Long ID_CONDUCTOR = 20L;

    @Mock
    private UsuarioRepository usuarioRepository;
    @Mock
    private ViajeService viajeService;

    @InjectMocks
    private ChatService chatService;

    /** Los metodos que no reciben el id de usuario lo sacan del SecurityContext, como en produccion. */
    @BeforeEach
    void autenticar() {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(new JwtUser(ID_PASAJERO, "ana", "PASAJERO"), null));
    }

    @AfterEach
    void limpiar() {
        SecurityContextHolder.clearContext();
    }

    private static Usuario usuario(Long id, String nombres, String apellidos) {
        Persona persona = new Persona();
        persona.setNombres(nombres);
        persona.setApellidos(apellidos);
        Usuario usuario = new Usuario();
        usuario.setId(id);
        usuario.setPersona(persona);
        usuario.setNombreUsuario("usuario" + id);
        return usuario;
    }

    private static Viaje viajeActivo() {
        Pasajero pasajero = new Pasajero();
        pasajero.setUsuario(usuario(ID_PASAJERO, "Ana", "Lopez"));
        Conductor conductor = new Conductor();
        conductor.setUsuario(usuario(ID_CONDUCTOR, "Carlos", "Perez"));
        Viaje viaje = new Viaje();
        viaje.setId(ID_VIAJE);
        viaje.setPasajero(pasajero);
        viaje.setConductor(conductor);
        viaje.setSituacionViaje(SituacionViaje.EN_CURSO);
        return viaje;
    }

    private void comoPasajero() {
        when(viajeService.obtenerViajeParaUsuario(ID_VIAJE, ID_PASAJERO)).thenReturn(viajeActivo());
        when(usuarioRepository.findById(ID_PASAJERO))
                .thenReturn(Optional.of(usuario(ID_PASAJERO, "Ana", "Lopez")));
    }

    private void comoConductor() {
        when(viajeService.obtenerViajeParaUsuario(ID_VIAJE, ID_CONDUCTOR)).thenReturn(viajeActivo());
        when(usuarioRepository.findById(ID_CONDUCTOR))
                .thenReturn(Optional.of(usuario(ID_CONDUCTOR, "Carlos", "Perez")));
    }

    @Test
    void enviarGuardaEnMemoriaYDevuelveAlConductorComoReceptor() {
        comoPasajero();

        ChatService.MensajeGuardado guardado =
                chatService.enviar(ID_PASAJERO, new MensajeEnvioRequest(ID_VIAJE, "  Estoy llegando  "));

        assertEquals("Estoy llegando", guardado.mensaje().contenido());
        assertEquals(ID_CONDUCTOR, guardado.idUsuarioReceptor());
        assertEquals("ANA LOPEZ", guardado.mensaje().nombreEmisor());
        assertEquals(ID_PASAJERO, guardado.mensaje().idUsuarioEmisor());
        assertFalse(guardado.mensaje().leido());

        when(viajeService.obtenerViajeDelUsuario(ID_VIAJE)).thenReturn(viajeActivo());
        assertEquals(1, chatService.historial(ID_VIAJE).size());
    }

    @Test
    void enviarDesdeElConductorDevuelveAlPasajeroComoReceptor() {
        comoConductor();

        ChatService.MensajeGuardado guardado =
                chatService.enviar(ID_CONDUCTOR, new MensajeEnvioRequest(ID_VIAJE, "Donde esta?"));

        assertEquals(ID_PASAJERO, guardado.idUsuarioReceptor());
        assertEquals("CARLOS PEREZ", guardado.mensaje().nombreEmisor());
    }

    @Test
    void enviarConViajeCompletadoSeNiegaYNoGuarda() {
        Viaje viaje = viajeActivo();
        viaje.setSituacionViaje(SituacionViaje.COMPLETADO);
        when(viajeService.obtenerViajeParaUsuario(ID_VIAJE, ID_PASAJERO)).thenReturn(viaje);

        assertThrows(NegocioException.class,
                () -> chatService.enviar(ID_PASAJERO, new MensajeEnvioRequest(ID_VIAJE, "Hola")));

        when(viajeService.obtenerViajeDelUsuario(ID_VIAJE)).thenReturn(viaje);
        assertTrue(chatService.historial(ID_VIAJE).isEmpty());
    }

    @Test
    void enviarConViajeCanceladoSeNiega() {
        Viaje viaje = viajeActivo();
        viaje.setSituacionViaje(SituacionViaje.CANCELADO);
        when(viajeService.obtenerViajeParaUsuario(ID_VIAJE, ID_PASAJERO)).thenReturn(viaje);

        assertThrows(NegocioException.class,
                () -> chatService.enviar(ID_PASAJERO, new MensajeEnvioRequest(ID_VIAJE, "Hola")));
    }

    @Test
    void enviarDeQuienNoEsParteDelViajeSeNiega() {
        when(viajeService.obtenerViajeParaUsuario(ID_VIAJE, 99L))
                .thenThrow(RecursoNoEncontradoException.de("Viaje", ID_VIAJE));

        assertThrows(RecursoNoEncontradoException.class,
                () -> chatService.enviar(99L, new MensajeEnvioRequest(ID_VIAJE, "Hola")));
    }

    @Test
    void historialDevuelveLosMensajesDelViajeDelMasViejoAlMasNuevo() {
        comoPasajero();
        comoConductor();
        when(viajeService.obtenerViajeDelUsuario(ID_VIAJE)).thenReturn(viajeActivo());

        chatService.enviar(ID_PASAJERO, new MensajeEnvioRequest(ID_VIAJE, "Primero"));
        chatService.enviar(ID_CONDUCTOR, new MensajeEnvioRequest(ID_VIAJE, "Segundo"));

        List<MensajeResponse> historial = chatService.historial(ID_VIAJE);

        assertEquals(2, historial.size());
        assertEquals("Primero", historial.getFirst().contenido());
        assertEquals("Segundo", historial.getLast().contenido());
        assertEquals(ID_VIAJE, historial.getFirst().idViaje());
    }

    @Test
    void historialDeViajeTerminadoSeVacia() {
        comoPasajero();
        chatService.enviar(ID_PASAJERO, new MensajeEnvioRequest(ID_VIAJE, "Hola"));

        Viaje terminado = viajeActivo();
        terminado.setSituacionViaje(SituacionViaje.COMPLETADO);
        when(viajeService.obtenerViajeDelUsuario(ID_VIAJE)).thenReturn(terminado);

        assertTrue(chatService.historial(ID_VIAJE).isEmpty());
    }

    @Test
    void marcarLeidosMarcaSoloLosDelOtro() {
        comoPasajero();
        comoConductor();
        when(viajeService.obtenerViajeDelUsuario(ID_VIAJE)).thenReturn(viajeActivo());
        chatService.enviar(ID_CONDUCTOR, new MensajeEnvioRequest(ID_VIAJE, "Del conductor"));
        chatService.enviar(ID_PASAJERO, new MensajeEnvioRequest(ID_VIAJE, "Del pasajero"));

        chatService.marcarLeidos(ID_VIAJE);

        List<MensajeResponse> historial = chatService.historial(ID_VIAJE);
        assertTrue(historial.getFirst().leido());
        assertFalse(historial.getLast().leido());
        assertEquals(0, chatService.contarNoLeidos(ID_VIAJE));
    }

    @Test
    void contarNoLeidosCuentaSoloLosQueDejoElOtro() {
        comoPasajero();
        comoConductor();
        when(viajeService.obtenerViajeDelUsuario(ID_VIAJE)).thenReturn(viajeActivo());
        chatService.enviar(ID_CONDUCTOR, new MensajeEnvioRequest(ID_VIAJE, "Uno"));
        chatService.enviar(ID_CONDUCTOR, new MensajeEnvioRequest(ID_VIAJE, "Dos"));
        chatService.enviar(ID_PASAJERO, new MensajeEnvioRequest(ID_VIAJE, "Mio"));

        assertEquals(2, chatService.contarNoLeidos(ID_VIAJE));
    }
}
