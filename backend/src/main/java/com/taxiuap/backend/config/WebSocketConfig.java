package com.taxiuap.backend.config;

import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessagingException;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

import com.taxiuap.backend.config.security.JwtService;
import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.config.security.TipoToken;

import lombok.RequiredArgsConstructor;

/**
 * Config de WebSocket (STOMP), usada por el dominio location (posicion GPS del conductor en
 * tiempo real) y por el chat de communication. A diferencia de uniFex no hay topics publicos:
 * todo el trafico de TaxiUAP requiere un usuario autenticado (pasajero, conductor o admin).
 */
@Configuration
@EnableWebSocketMessageBroker
@RequiredArgsConstructor
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    private final JwtService jwtService;

    @Value("${cors.origenes:}")
    private String origenesCors;

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        config.enableSimpleBroker("/topic", "/queue")
                .setHeartbeatValue(new long[] { 10_000, 10_000 })
                .setTaskScheduler(programadorLatidos());
        config.setApplicationDestinationPrefixes("/app");
        config.setUserDestinationPrefix("/user");
    }

    /** Hilo propio para los latidos y no un @Bean, para no interferir con otros TaskScheduler. */
    private ThreadPoolTaskScheduler programadorLatidos() {
        ThreadPoolTaskScheduler scheduler = new ThreadPoolTaskScheduler();
        scheduler.setPoolSize(1);
        scheduler.setThreadNamePrefix("ws-latido-");
        scheduler.setDaemon(true);
        scheduler.initialize();
        return scheduler;
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // Origenes de la propiedad cors.origenes; si viene vacia se permite cualquier origen
        // ("*") porque las apps moviles (Flutter/Android) no mandan cabecera Origin como un
        // navegador, asi que no hay lista fija que proteja nada en ese caso.
        String origenes = (origenesCors == null || origenesCors.isBlank()) ? "*" : origenesCors;
        registry.addEndpoint("/ws").setAllowedOriginPatterns(origenes.split("\\s*,\\s*"));
    }

    /**
     * Autentica el WebSocket en el frame STOMP CONNECT (no en el handshake HTTP): la API
     * WebSocket del navegador no permite agregar cabeceras propias al handshake, pero el frame
     * CONNECT si lleva las cabeceras nativas que el cliente STOMP le pasa en connectHeaders.
     *
     * Sin cabecera Authorization, mal formada o con token invalido/expirado se rechaza el
     * CONNECT (no hay sesion anonima en TaxiUAP). SUBSCRIBE y SEND sin usuario tambien se
     * rechazan.
     */
    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new ChannelInterceptor() {
            @Override
            public Message<?> preSend(Message<?> mensaje, MessageChannel canal) {
                StompHeaderAccessor acc = MessageHeaderAccessor.getAccessor(mensaje, StompHeaderAccessor.class);
                if (acc == null || acc.getCommand() == null) {
                    return mensaje;
                }
                if (StompCommand.CONNECT.equals(acc.getCommand())) {
                    autenticar(acc);
                } else if (StompCommand.SUBSCRIBE.equals(acc.getCommand())
                        || StompCommand.SEND.equals(acc.getCommand())) {
                    exigirUsuario(acc);
                }
                return mensaje;
            }
        });
    }

    private void autenticar(StompHeaderAccessor acc) {
        String cabecera = acc.getFirstNativeHeader("Authorization");
        if (cabecera == null || !cabecera.startsWith("Bearer ")) {
            throw new MessagingException("Cabecera Authorization ausente o mal formada en el CONNECT");
        }
        try {
            JwtUser usuario = jwtService.validar(cabecera.substring(7), TipoToken.ACCESO);
            acc.setUser(new UsernamePasswordAuthenticationToken(
                    usuario, null, List.of(new SimpleGrantedAuthority("ROLE_" + usuario.rol()))));
        } catch (Exception e) {
            throw new MessagingException("Token invalido o expirado");
        }
    }

    private void exigirUsuario(StompHeaderAccessor acc) {
        if (acc.getUser() == null) {
            throw new MessagingException("Se requiere autenticacion para " + acc.getCommand());
        }
    }
}
