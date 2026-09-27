package com.taxiuap.backend.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

import com.taxiuap.backend.config.security.JwtService;

import lombok.RequiredArgsConstructor;

/**
 * Config de WebSocket (STOMP), usada por el dominio location (posicion GPS del conductor en
 * tiempo real) y por el chat de communication. A diferencia de uniFex no hay topics publicos:
 * todo el trafico de TaxiUAP requiere un usuario autenticado (pasajero, conductor o admin).
 *
 * La autenticacion y el gate de administrador viven en
 * {@link InterceptorWebSocketSeguridad}, aparte, para que se puedan probar sin levantar el broker.
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

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new InterceptorWebSocketSeguridad(jwtService));
    }
}
