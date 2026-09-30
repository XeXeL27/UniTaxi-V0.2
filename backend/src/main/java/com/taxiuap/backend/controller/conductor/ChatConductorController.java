package com.taxiuap.backend.controller.conductor;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.communication.dto.MensajeResponse;
import com.taxiuap.backend.communication.service.ChatService;
import com.taxiuap.backend.shared.response.ApiResponse;

import lombok.RequiredArgsConstructor;

/** Chat del conductor con el pasajero del viaje. */
@RestController
@RequestMapping("/api/conductor/viajes/{idViaje}/mensajes")
@RequiredArgsConstructor
public class ChatConductorController {

    private final ChatService chatService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<MensajeResponse>>> historial(@PathVariable Long idViaje) {
        return ResponseEntity.ok(ApiResponse.exito(chatService.historial(idViaje)));
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
