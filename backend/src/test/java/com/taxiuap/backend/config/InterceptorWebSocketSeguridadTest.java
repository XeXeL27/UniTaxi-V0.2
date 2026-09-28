package com.taxiuap.backend.config;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessagingException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import com.taxiuap.backend.config.security.JwtService;
import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.config.security.TipoToken;

import io.jsonwebtoken.JwtException;

@ExtendWith(MockitoExtension.class)
class InterceptorWebSocketSeguridadTest {

    private static final String TOKEN = "un-token-jwt";

    @Mock
    private JwtService jwtService;

    private ChannelInterceptor interceptor;

    @BeforeEach
    void preparar() {
        interceptor = new InterceptorWebSocketSeguridad(jwtService);
    }

    private static Message<?> frame(StompCommand comando, String destino, String token) {
        StompHeaderAccessor acc = StompHeaderAccessor.create(comando);
        acc.setDestination(destino);
        if (token != null) {
            acc.setNativeHeader("Authorization", "Bearer " + token);
        }
        acc.setLeaveMutable(true);
        return MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());
    }

    private static void autenticar(Object acc, String rol) {
        ((StompHeaderAccessor) acc).setUser(new UsernamePasswordAuthenticationToken(
                new JwtUser(1L, "usuario", rol), null,
                List.of(new SimpleGrantedAuthority("ROLE_" + rol))));
    }

    // -------------------------------------------------------------- CONNECT

    @Test
    void aceptaElConnectConTokenValido() {
        when(jwtService.validar(anyString(), any())).thenReturn(new JwtUser(1L, "admin", "ADMIN"));

        StompHeaderAccessor acc = StompHeaderAccessor.create(StompCommand.CONNECT);
        acc.setNativeHeader("Authorization", "Bearer " + TOKEN);
        acc.setLeaveMutable(true);
        Message<?> mensaje = MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());

        assertDoesNotThrow(() -> interceptor.preSend(mensaje, null));
    }

    @Test
    void rechazaElConnectSinCabecera() {
        Message<?> mensaje = frame(StompCommand.CONNECT, null, null);

        assertThrows(MessagingException.class, () -> interceptor.preSend(mensaje, null));
    }

    @Test
    void rechazaElConnectConCabeceraMalFormada() {
        StompHeaderAccessor acc = StompHeaderAccessor.create(StompCommand.CONNECT);
        acc.setNativeHeader("Authorization", "basura");
        acc.setLeaveMutable(true);
        Message<?> mensaje = MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());

        assertThrows(MessagingException.class, () -> interceptor.preSend(mensaje, null));
    }

    @Test
    void rechazaElConnectConTokenInvalido() {
        when(jwtService.validar(anyString(), any())).thenThrow(new JwtException("invalido"));

        Message<?> mensaje = frame(StompCommand.CONNECT, null, TOKEN);

        assertThrows(MessagingException.class, () -> interceptor.preSend(mensaje, null));
    }

    // -------------------------------------------------------------- SUBSCRIBE

    @Test
    void elAdminPuedeSuscribirseAlTopicDeAdministradores() {
        StompHeaderAccessor acc = StompHeaderAccessor.create(StompCommand.SUBSCRIBE);
        acc.setDestination("/topic/admin/conductores");
        acc.setLeaveMutable(true);
        Message<?> mensaje = MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());
        autenticar(acc, "ADMIN");

        assertDoesNotThrow(() -> interceptor.preSend(mensaje, null));
    }

    @Test
    void unConductorNoPuedeSuscribirseAlTopicDeAdministradores() {
        StompHeaderAccessor acc = StompHeaderAccessor.create(StompCommand.SUBSCRIBE);
        acc.setDestination("/topic/admin/conductores");
        acc.setLeaveMutable(true);
        Message<?> mensaje = MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());
        autenticar(acc, "CONDUCTOR");

        assertThrows(MessagingException.class, () -> interceptor.preSend(mensaje, null));
    }

    @Test
    void unPasajeroNoPuedeSuscribirseAlTopicDeAdministradores() {
        StompHeaderAccessor acc = StompHeaderAccessor.create(StompCommand.SUBSCRIBE);
        acc.setDestination("/topic/admin/conductores");
        acc.setLeaveMutable(true);
        Message<?> mensaje = MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());
        autenticar(acc, "PASAJERO");

        assertThrows(MessagingException.class, () -> interceptor.preSend(mensaje, null));
    }

    @Test
    void cualquierRolAutenticadoPuedeSuscribirseAUnTopicNormal() {
        StompHeaderAccessor acc = StompHeaderAccessor.create(StompCommand.SUBSCRIBE);
        acc.setDestination("/topic/solicitudes");
        acc.setLeaveMutable(true);
        Message<?> mensaje = MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());
        autenticar(acc, "CONDUCTOR");

        assertDoesNotThrow(() -> interceptor.preSend(mensaje, null));
    }

    @Test
    void rechazaSuscribirseSinAutenticar() {
        Message<?> mensaje = frame(StompCommand.SUBSCRIBE, "/topic/admin/conductores", null);

        assertThrows(MessagingException.class, () -> interceptor.preSend(mensaje, null));
    }

    // -------------------------------------------------------------- SEND y otros

    @Test
    void cualquierRolAutenticadoPuedeEnviar() {
        StompHeaderAccessor acc = StompHeaderAccessor.create(StompCommand.SEND);
        acc.setDestination("/app/conductor/ubicacion");
        acc.setLeaveMutable(true);
        Message<?> mensaje = MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());
        autenticar(acc, "CONDUCTOR");

        assertDoesNotThrow(() -> interceptor.preSend(mensaje, null));
    }

    @Test
    void rechazaEnviarSinAutenticar() {
        Message<?> mensaje = frame(StompCommand.SEND, "/app/conductor/ubicacion", null);

        assertThrows(MessagingException.class, () -> interceptor.preSend(mensaje, null));
    }

    @Test
    void dejaPasarLosLatidos() {
        Message<?> mensaje = frame(StompCommand.DISCONNECT, null, null);

        assertDoesNotThrow(() -> interceptor.preSend(mensaje, null));

        verify(jwtService, never()).validar(any(), any());
    }
}
