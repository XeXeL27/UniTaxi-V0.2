package com.taxiuap.backend.communication.service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.communication.dto.MensajeEnvioRequest;
import com.taxiuap.backend.communication.dto.MensajeResponse;
import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.service.ViajeService;

import lombok.RequiredArgsConstructor;

/**
 * Chat en memoria entre el pasajero y el conductor de un viaje.
 *
 * Los mensajes no se persisten: viven en un mapa por viaje mientras el backend esta levantado y
 * se pierden al reiniciar. Es a proposito: el chat solo sirve para coordinar la recogida durante
 * el viaje, y al no tocar la base de datos el envio por WebSocket no depende del SecurityContext
 * del hilo (que en STOMP no existe).
 *
 * La entidad mensaje, su repositorio y el seed quedan intactos para el modelo de datos; este
 * servicio simplemente no los usa. La anotacion @Transactional no es para guardar (no hay nada que
 * guardar): mantiene la sesion de Hibernate abierta mientras se leen los entities (la persona del
 * emisor es perezosa), igual que el resto de servicios.
 *
 * Este servicio solo valida y guarda en memoria; la entrega en tiempo real la hace el controlador
 * de WebSocket, que reenvia cada mensaje a las colas de los dos participantes.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ChatService {

    /** Tope de mensajes por viaje: la conversacion es corta y el mapa no debe crecer sin limite. */
    private static final int MAX_MENSAJES = 200;

    private final UsuarioRepository usuarioRepository;
    private final ViajeService viajeService;

    private final Map<Long, List<Entrada>> conversaciones = new ConcurrentHashMap<>();
    private final AtomicLong secuencia = new AtomicLong();

    /** Guarda el mensaje del emisor y lo devuelve, junto al usuario al que hay que reenviarlo. */
    @Transactional
    public MensajeGuardado enviar(Long idUsuarioEmisor, MensajeEnvioRequest request) {
        Viaje viaje = viajeService.obtenerViajeParaUsuario(request.idViaje(), idUsuarioEmisor);
        if (viaje.getSituacionViaje() == SituacionViaje.COMPLETADO
                || viaje.getSituacionViaje() == SituacionViaje.CANCELADO) {
            conversaciones.remove(request.idViaje());
            throw new NegocioException("El viaje ya termino y el chat esta cerrado");
        }

        Usuario emisor = usuarioRepository.findById(idUsuarioEmisor)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", idUsuarioEmisor));

        Entrada entrada = new Entrada(
                secuencia.incrementAndGet(),
                idUsuarioEmisor,
                nombreDe(emisor),
                request.contenido().trim(),
                LocalDateTime.now());
        agregar(request.idViaje(), entrada);

        return new MensajeGuardado(
                new MensajeResponse(entrada.id(), request.idViaje(), entrada.idEmisor(),
                        entrada.nombreEmisor(), entrada.contenido(), entrada.leido(), entrada.fecha()),
                idReceptor(viaje, idUsuarioEmisor));
    }

    /** Historial del viaje, del mas viejo al mas nuevo. */
    public List<MensajeResponse> historial(Long idViaje) {
        Viaje viaje = viajeService.obtenerViajeDelUsuario(idViaje);
        if (terminado(viaje)) {
            conversaciones.remove(idViaje);
            return List.of();
        }
        return aRespuestas(idViaje);
    }

    /** Marca como leidos los mensajes que el otro participante le dejo al usuario. */
    public void marcarLeidos(Long idViaje) {
        Long idUsuario = UsuarioActual.idUsuario();
        viajeService.obtenerViajeDelUsuario(idViaje);
        List<Entrada> entradas = conversaciones.get(idViaje);
        if (entradas == null) {
            return;
        }
        synchronized (entradas) {
            for (Entrada entrada : entradas) {
                if (!entrada.idEmisor().equals(idUsuario)) {
                    entrada.leido(true);
                }
            }
        }
    }

    /** Mensajes sin leer que le dejaron al usuario: el numero del badge del boton de chat. */
    public long contarNoLeidos(Long idViaje) {
        Long idUsuario = UsuarioActual.idUsuario();
        viajeService.obtenerViajeDelUsuario(idViaje);
        List<Entrada> entradas = conversaciones.get(idViaje);
        if (entradas == null) {
            return 0;
        }
        synchronized (entradas) {
            return entradas.stream()
                    .filter(entrada -> !entrada.leido() && !entrada.idEmisor().equals(idUsuario))
                    .count();
        }
    }

    /** El otro participante del viaje: a quien se lo reenvia el controlador de WebSocket. */
    private Long idReceptor(Viaje viaje, Long idEmisor) {
        return viaje.getPasajero().getUsuario().getId().equals(idEmisor)
                ? viaje.getConductor().getUsuario().getId()
                : viaje.getPasajero().getUsuario().getId();
    }

    private void agregar(Long idViaje, Entrada entrada) {
        List<Entrada> entradas = conversaciones.computeIfAbsent(
                idViaje, clave -> new ArrayList<>());
        synchronized (entradas) {
            entradas.add(entrada);
            while (entradas.size() > MAX_MENSAJES) {
                entradas.removeFirst();
            }
        }
    }

    private List<MensajeResponse> aRespuestas(Long idViaje) {
        List<Entrada> entradas = conversaciones.get(idViaje);
        if (entradas == null) {
            return List.of();
        }
        synchronized (entradas) {
            return entradas.stream()
                    .map(entrada -> new MensajeResponse(
                            entrada.id(), idViaje, entrada.idEmisor(), entrada.nombreEmisor(),
                            entrada.contenido(), entrada.leido(), entrada.fecha()))
                    .toList();
        }
    }

    private static boolean terminado(Viaje viaje) {
        return viaje.getSituacionViaje() == SituacionViaje.COMPLETADO
                || viaje.getSituacionViaje() == SituacionViaje.CANCELADO;
    }

    private static String nombreDe(Usuario usuario) {
        if (usuario.getPersona() == null) {
            return usuario.getNombreUsuario();
        }
        return (usuario.getPersona().getNombres() + " " + usuario.getPersona().getApellidos()).trim();
    }

    /** Mensaje en memoria: id correlativo, emisor, texto, fecha y si el otro ya lo vio. */
    private static final class Entrada {
        private final long id;
        private final Long idEmisor;
        private final String nombreEmisor;
        private final String contenido;
        private final LocalDateTime fecha;
        private volatile boolean leido;

        private Entrada(long id, Long idEmisor, String nombreEmisor, String contenido, LocalDateTime fecha) {
            this.id = id;
            this.idEmisor = idEmisor;
            this.nombreEmisor = nombreEmisor;
            this.contenido = contenido;
            this.fecha = fecha;
        }

        private long id() {
            return id;
        }

        private Long idEmisor() {
            return idEmisor;
        }

        private String nombreEmisor() {
            return nombreEmisor;
        }

        private String contenido() {
            return contenido;
        }

        private LocalDateTime fecha() {
            return fecha;
        }

        private boolean leido() {
            return leido;
        }

        private void leido(boolean leido) {
            this.leido = leido;
        }
    }

    /** Mensaje guardado mas el usuario al que hay que reenviarlo por WebSocket. */
    public record MensajeGuardado(MensajeResponse mensaje, Long idUsuarioReceptor) {
    }
}
