package com.taxiuap.backend.config;

import java.util.List;

import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessagingException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import com.taxiuap.backend.config.security.JwtService;
import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.config.security.TipoToken;

import lombok.RequiredArgsConstructor;

/**
 * Autentica y autoriza el trafico de WebSocket.
 *
 * La autenticacion va en el frame CONNECT y no en el handshake HTTP porque la API WebSocket del
 * navegador no permite agregar cabeceras propias, pero el frame CONNECT si lleva las cabeceras
 * nativas que el cliente STOMP le pasa en connectHeaders. Sin cabecera Authorization, mal formada
 * o con token invalido o expirado, se rechaza el CONNECT: no hay sesion anonima en TaxiUAP.
 *
 * Los destinos que empiezan por /topic/admin/ son solo para administradores. Se rechaza la
 * suscripcion de cualquiera con otro rol aunque tenga un token valido, que es lo que protege el
 * mapa de flota del panel. El resto de topics sigue abierto a cualquier usuario autenticado.
 */
@RequiredArgsConstructor
public class InterceptorWebSocketSeguridad implements ChannelInterceptor {

    private static final String PREFIJO_ADMIN = "/topic/admin/";
    private static final String AUTORIDAD_ADMIN = "ROLE_" + RolSistema.ADMIN.getCodigo();

    private final JwtService jwtService;

    @Override
    public Message<?> preSend(Message<?> mensaje, MessageChannel canal) {
        StompHeaderAccessor acc = MessageHeaderAccessor.getAccessor(mensaje, StompHeaderAccessor.class);
        if (acc == null || acc.getCommand() == null) {
            return mensaje;
        }
        if (StompCommand.CONNECT.equals(acc.getCommand())) {
            autenticar(acc);
        } else if (StompCommand.SUBSCRIBE.equals(acc.getCommand())) {
            exigirUsuario(acc);
            exigirAdminSiCorresponde(acc);
        } else if (StompCommand.SEND.equals(acc.getCommand())) {
            exigirUsuario(acc);
        }
        return mensaje;
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

    private void exigirAdminSiCorresponde(StompHeaderAccessor acc) {
        String destino = acc.getDestination();
        if (destino == null || !destino.startsWith(PREFIJO_ADMIN)) {
            return;
        }
        // getUser() devuelve un Principal a secas, que no expone las autoridades: hay que mirar
        // dentro de la Authentication que el CONNECT dejo como principal.
        if (!(acc.getUser() instanceof Authentication autenticacion)
                || autenticacion.getAuthorities().stream()
                        .noneMatch(autoridad -> AUTORIDAD_ADMIN.equals(autoridad.getAuthority()))) {
            throw new MessagingException("El destino " + destino + " es solo para administradores");
        }
    }
}
