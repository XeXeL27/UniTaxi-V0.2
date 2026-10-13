package com.taxiuap.backend.communication.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.communication.dto.MensajeEnvioRequest;
import com.taxiuap.backend.communication.dto.MensajeResponse;
import com.taxiuap.backend.communication.entity.Mensaje;
import com.taxiuap.backend.communication.repository.MensajeRepository;
import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.service.ViajeService;

import lombok.RequiredArgsConstructor;

/** Chat persistente entre el pasajero y el conductor de un viaje. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ChatService {

    private final UsuarioRepository usuarioRepository;
    private final MensajeRepository mensajeRepository;
    private final ViajeService viajeService;
    private final NotificacionPushService notificacionPushService;

    /** Guarda el mensaje del emisor y lo devuelve, junto al usuario al que hay que reenviarlo. */
    @Transactional
    public MensajeGuardado enviar(Long idUsuarioEmisor, MensajeEnvioRequest request) {
        Viaje viaje = viajeService.obtenerViajeParaUsuario(request.idViaje(), idUsuarioEmisor);
        if (viaje.getSituacionViaje() == SituacionViaje.COMPLETADO
                || viaje.getSituacionViaje() == SituacionViaje.CANCELADO) {
            throw new NegocioException("El viaje ya termino y el chat esta cerrado");
        }

        Usuario emisor = usuarioRepository.findById(idUsuarioEmisor)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", idUsuarioEmisor));

        // CAMBIO CODEX 2026-10-07: el chat deja de depender de memoria y sobrevive al reinicio.
        Mensaje entidad = new Mensaje();
        entidad.setViaje(viaje);
        entidad.setUsuarioEmisor(emisor);
        entidad.setContenido(request.contenido().trim());
        entidad.setLeido(false);
        entidad.setFecha(LocalDateTime.now());
        Mensaje guardado = mensajeRepository.save(entidad);
        Long idReceptor = idReceptor(viaje, idUsuarioEmisor);
        avisarPorPush(guardado, idReceptor);

        return new MensajeGuardado(respuesta(guardado), idReceptor);
    }

    /** Historial del viaje, del mas viejo al mas nuevo. */
    public List<MensajeResponse> historial(Long idViaje) {
        return historial(idViaje, null);
    }

    /**
     * Historial del viaje; con [desde] solo los mensajes posteriores a ese id. La app lo consulta
     * cada pocos segundos cuando el WebSocket no conecta, y al reconectarse o volver a la app, para
     * traer lo que llego mientras tanto.
     */
    public List<MensajeResponse> historial(Long idViaje, Long desde) {
        Viaje viaje = viajeService.obtenerViajeDelUsuario(idViaje);
        if (terminado(viaje)) {
            return List.of();
        }
        List<Mensaje> mensajes = desde == null
                ? mensajeRepository.findByViajeIdOrderByFechaAsc(idViaje)
                : mensajeRepository.findByViajeIdAndIdGreaterThanOrderByIdAsc(idViaje, desde);
        return mensajes.stream().map(ChatService::respuesta).toList();
    }

    /**
     * Push al otro participante: con la app minimizada o cerrada le llega "Mensaje de Rene" aunque el
     * WebSocket este cortado. Con la app abierta el aviso lo da el chat y el push no se muestra.
     */
    private void avisarPorPush(Mensaje mensaje, Long idReceptor) {
        String contenido = mensaje.getContenido();
        notificacionPushService.enviar(idReceptor, Map.of(
                "tipo", "CHAT_MENSAJE",
                "idViaje", String.valueOf(mensaje.getViaje().getId()),
                "idMensaje", String.valueOf(mensaje.getId()),
                "titulo", "Mensaje de " + primerNombre(mensaje.getUsuarioEmisor()),
                "cuerpo", contenido.length() > 200 ? contenido.substring(0, 200) + "..." : contenido));
    }

    /** "Rene", no "RENE": los nombres se guardan en mayusculas. */
    private static String primerNombre(Usuario usuario) {
        String nombres = usuario.getPersona() == null ? null : usuario.getPersona().getNombres();
        if (nombres == null || nombres.isBlank()) {
            return usuario.getNombreUsuario();
        }
        String primero = nombres.trim().split("\\s+")[0].toLowerCase(Locale.forLanguageTag("es"));
        return Character.toUpperCase(primero.charAt(0)) + primero.substring(1);
    }

    /** Marca como leidos los mensajes que el otro participante le dejo al usuario. */
    @Transactional
    public void marcarLeidos(Long idViaje) {
        Long idUsuario = UsuarioActual.idUsuario();
        viajeService.obtenerViajeDelUsuario(idViaje);
        mensajeRepository.marcarLeidosDelOtro(idViaje, idUsuario);
    }

    /** Mensajes sin leer que le dejaron al usuario: el numero del badge del boton de chat. */
    public long contarNoLeidos(Long idViaje) {
        Long idUsuario = UsuarioActual.idUsuario();
        viajeService.obtenerViajeDelUsuario(idViaje);
        return mensajeRepository.countByViajeIdAndLeidoFalseAndUsuarioEmisorIdNot(idViaje, idUsuario);
    }

    /** El otro participante del viaje: a quien se lo reenvia el controlador de WebSocket. */
    private Long idReceptor(Viaje viaje, Long idEmisor) {
        return viaje.getPasajero().getUsuario().getId().equals(idEmisor)
                ? viaje.getConductor().getUsuario().getId()
                : viaje.getPasajero().getUsuario().getId();
    }

    private static MensajeResponse respuesta(Mensaje mensaje) {
        return new MensajeResponse(
                mensaje.getId(),
                mensaje.getViaje().getId(),
                mensaje.getUsuarioEmisor().getId(),
                nombreDe(mensaje.getUsuarioEmisor()),
                mensaje.getContenido(),
                Boolean.TRUE.equals(mensaje.getLeido()),
                mensaje.getFecha());
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

    /** Mensaje guardado mas el usuario al que hay que reenviarlo por WebSocket. */
    public record MensajeGuardado(MensajeResponse mensaje, Long idUsuarioReceptor) {
    }
}
