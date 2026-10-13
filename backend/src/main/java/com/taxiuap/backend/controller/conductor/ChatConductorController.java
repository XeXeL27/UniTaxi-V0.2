package com.taxiuap.backend.controller.conductor;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.communication.dto.MensajeEnvioRequest;
import com.taxiuap.backend.communication.dto.MensajeResponse;
import com.taxiuap.backend.communication.dto.MensajeTextoRequest;
import com.taxiuap.backend.communication.service.ChatService;
import com.taxiuap.backend.communication.service.ReenvioChatService;
import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.shared.response.ApiResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/** Chat del conductor con el pasajero del viaje. */
@RestController
@RequestMapping("/api/conductor/viajes/{idViaje}/mensajes")
@RequiredArgsConstructor
public class ChatConductorController {

    private final ChatService chatService;
    private final ReenvioChatService reenvioChatService;

    /** Historial; con desde, solo los mensajes posteriores a ese id (consulta de respaldo de la app). */
    @GetMapping
    public ResponseEntity<ApiResponse<List<MensajeResponse>>> historial(
            @PathVariable Long idViaje, @RequestParam(required = false) Long desde) {
        return ResponseEntity.ok(ApiResponse.exito(chatService.historial(idViaje, desde)));
    }

    /** Envio por REST: funciona aunque el WebSocket no conecte; se reenvia en vivo a los dos. */
    @PostMapping
    public ResponseEntity<ApiResponse<MensajeResponse>> enviar(
            @PathVariable Long idViaje, @Valid @RequestBody MensajeTextoRequest request) {
        ChatService.MensajeGuardado guardado = chatService.enviar(
                UsuarioActual.idUsuario(), new MensajeEnvioRequest(idViaje, request.contenido()));
        reenvioChatService.reenviar(guardado);
        return ResponseEntity.ok(ApiResponse.exito(guardado.mensaje()));
    }

    @PostMapping("/leidos")
    public ResponseEntity<ApiResponse<Void>> marcarLeidos(@PathVariable Long idViaje) {
        chatService.marcarLeidos(idViaje);
        return ResponseEntity.ok(ApiResponse.exito("Mensajes marcados como leidos", null));
    }

    @GetMapping("/no-leidos")
    public ResponseEntity<ApiResponse<Long>> contarNoLeidos(@PathVariable Long idViaje) {
        return ResponseEntity.ok(ApiResponse.exito(chatService.contarNoLeidos(idViaje)));
    }
}
