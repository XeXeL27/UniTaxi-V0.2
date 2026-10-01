package com.taxiuap.backend.communication.service;

import java.nio.charset.StandardCharsets;

import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionalEventListener;

import jakarta.mail.internet.InternetAddress;
import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Envio de correos. El correo se encola como evento y sale en segundo plano recien cuando la
 * transaccion que lo pidio termina bien: si el registro falla no llega un correo con credenciales
 * que no existen, y si el SMTP falla el registro no se pierde (solo queda en el log).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CorreoService {

    public record CorreoPendiente(String para, String asunto, String cuerpo) {
    }

    private final ApplicationEventPublisher eventos;
    private final ObjectProvider<JavaMailSender> mailSender;

    @Value("${spring.mail.username:}")
    private String remitente;

    @Value("${taxiuap.correo.remitente-nombre:UNITAXI}")
    private String nombreRemitente;

    public void enviar(String para, String asunto, String cuerpo) {
        if (para == null || para.isBlank()) return;
        eventos.publishEvent(new CorreoPendiente(para.trim(), asunto, cuerpo));
    }

    @Async
    @TransactionalEventListener(fallbackExecution = true)
    public void alConfirmar(CorreoPendiente correo) {
        JavaMailSender sender = mailSender.getIfAvailable();
        if (sender == null || remitente == null || remitente.isBlank()) {
            log.warn("Correo sin configurar (spring.mail.username): no se envio '{}' a {}", correo.asunto(), correo.para());
            return;
        }
        try {
            MimeMessage mensaje = sender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(mensaje, false, StandardCharsets.UTF_8.name());
            helper.setFrom(new InternetAddress(remitente, nombreRemitente, StandardCharsets.UTF_8.name()));
            helper.setTo(correo.para());
            helper.setSubject(correo.asunto());
            helper.setText(correo.cuerpo(), false);
            sender.send(mensaje);
            log.info("Correo '{}' enviado a {}", correo.asunto(), correo.para());
        } catch (Exception e) {
            log.error("No se pudo enviar el correo '{}' a {}: {}", correo.asunto(), correo.para(), e.getMessage());
        }
    }
}
