package com.taxiuap.backend.communication.service;

import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionalEventListener;

import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.taxiuap.backend.identity.entity.Dispositivo;
import com.taxiuap.backend.identity.repository.DispositivoRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Notificaciones push (Firebase Cloud Messaging) a los telefonos de un usuario: llegan aunque la app
 * este cerrada. Se encolan como evento y salen en segundo plano cuando la transaccion termina bien
 * (igual que CorreoService); si Firebase falla, el viaje sigue igual y solo queda en el log.
 *
 * Son mensajes de datos: la app arma la notificacion con el sonido y la vibracion que eligio la
 * persona (Mas > Sonido y vibracion). La llave de la cuenta de servicio va fuera del repositorio:
 * taxiuap.fcm.credenciales / FIREBASE_CREDENCIALES, o el primer JSON de ../taxiuap-secretos. Sin
 * llave, las notificaciones push quedan apagadas (la app igual avisa mientras esta abierta).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class NotificacionPushService {

    /** Aviso pendiente de enviar a todos los telefonos activos de un usuario. */
    public record PushPendiente(Long idUsuario, Map<String, String> datos) {
    }

    private final ApplicationEventPublisher eventos;
    private final DispositivoRepository dispositivoRepository;

    @Value("${taxiuap.fcm.credenciales:${FIREBASE_CREDENCIALES:}}")
    private String rutaCredenciales;

    private FirebaseMessaging mensajeria;

    @PostConstruct
    void iniciar() {
        Path llave = buscarLlave();
        if (llave == null) {
            log.warn("Notificaciones push apagadas: falta la llave de Firebase (FIREBASE_CREDENCIALES)");
            return;
        }
        try (InputStream entrada = new FileInputStream(llave.toFile())) {
            // Cliente HTTP estandar de Java: el de Apache (httpclient5 de Spring Boot 4) ya descomprime
            // la respuesta y la libreria de Google intentaba descomprimirla otra vez ("Not in GZIP format").
            NetHttpTransport transporte = new NetHttpTransport();
            FirebaseOptions opciones = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(entrada, () -> transporte))
                    .setHttpTransport(transporte)
                    .build();
            FirebaseApp app = FirebaseApp.getApps().isEmpty()
                    ? FirebaseApp.initializeApp(opciones)
                    : FirebaseApp.getInstance();
            mensajeria = FirebaseMessaging.getInstance(app);
            log.info("Notificaciones push activas (Firebase, llave {})", llave.getFileName());
        } catch (Exception e) {
            log.error("No se pudo iniciar Firebase con {}: {}", llave.getFileName(), e.getMessage());
        }
    }

    private Path buscarLlave() {
        if (rutaCredenciales != null && !rutaCredenciales.isBlank()) {
            Path ruta = Path.of(rutaCredenciales.trim());
            if (Files.isRegularFile(ruta)) return ruta;
            log.warn("La llave de Firebase no existe: {}", ruta);
        }
        for (Path carpeta : List.of(Path.of("taxiuap-secretos"), Path.of("..", "taxiuap-secretos"))) {
            if (!Files.isDirectory(carpeta)) continue;
            try (DirectoryStream<Path> archivos = Files.newDirectoryStream(carpeta, "*.json")) {
                for (Path archivo : archivos) {
                    if (Files.readString(archivo).contains("\"service_account\"")) return archivo.toAbsolutePath();
                }
            } catch (Exception e) {
                log.warn("No se pudo revisar {}: {}", carpeta, e.getMessage());
            }
        }
        return null;
    }

    public boolean activo() {
        return mensajeria != null;
    }

    /** Encola el aviso; sale despues del commit de la transaccion actual. */
    public void enviar(Long idUsuario, Map<String, String> datos) {
        if (idUsuario == null || mensajeria == null) return;
        eventos.publishEvent(new PushPendiente(idUsuario, datos));
    }

    @Async
    @TransactionalEventListener(fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void alConfirmar(PushPendiente aviso) {
        List<Dispositivo> dispositivos = dispositivoRepository.findByUsuarioId(aviso.idUsuario()).stream()
                .filter(d -> d.getEstadoDispos() == EstadoRegistro.A)
                .toList();
        for (Dispositivo dispositivo : dispositivos) {
            Message mensaje = Message.builder()
                    .setToken(dispositivo.getTokenFcm())
                    .putAllData(aviso.datos())
                    // Prioridad alta: despierta al telefono aunque este en reposo; si en un minuto no
                    // llega, ya no sirve (el viaje siguio).
                    .setAndroidConfig(AndroidConfig.builder()
                            .setPriority(AndroidConfig.Priority.HIGH)
                            .setTtl(60_000)
                            .build())
                    .build();
            try {
                mensajeria.send(mensaje);
            } catch (FirebaseMessagingException e) {
                MessagingErrorCode codigo = e.getMessagingErrorCode();
                if (codigo == MessagingErrorCode.UNREGISTERED || codigo == MessagingErrorCode.INVALID_ARGUMENT) {
                    // La app se desinstalo o el token cambio: no se vuelve a usar.
                    dispositivo.setEstadoDispos(EstadoRegistro.X);
                    dispositivoRepository.save(dispositivo);
                } else {
                    log.warn("No se pudo enviar el push {} al usuario {}: {}", aviso.datos().get("tipo"),
                            aviso.idUsuario(), e.getMessage());
                }
            } catch (Exception e) {
                log.warn("No se pudo enviar el push al usuario {}: {}", aviso.idUsuario(), e.getMessage());
            }
        }
    }
}
