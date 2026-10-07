package com.taxiuap.backend.controller.admin;

import java.time.LocalDate;
import java.util.List;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.shared.response.ApiResponse;
import com.taxiuap.backend.trip.dto.PersonaViajesResponse;
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.service.ViajeService;

import lombok.RequiredArgsConstructor;

/** Viajes de taxi y pedidos de delivery en el panel, con filtros por servicio, persona y fechas. */
@RestController
@RequestMapping("/api/admin/viajes")
@RequiredArgsConstructor
public class ViajeAdminController {

    private final ViajeService viajeService;

    /**
     * servicio: TODOS, TAXI o DELIVERY. tipoUsuario: TODOS, PASAJERO, CONDUCTOR (taxi) o REPARTIDOR; con
     * idPersona solo los de esa persona. desde / hasta (AAAA-MM-DD, incluidos): sin ellas, todo.
     */
    @GetMapping
    public ResponseEntity<ApiResponse<List<ViajeResponse>>> listar(
            @RequestParam(defaultValue = "TODOS") String servicio,
            @RequestParam(defaultValue = "TODOS") String tipoUsuario,
            @RequestParam(required = false) Long idPersona,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta) {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.listarParaAdmin(servicio, tipoUsuario, idPersona, desde,
                hasta)));
    }

    /** Personas para el filtro: tipoUsuario PASAJERO, CONDUCTOR (taxi) o REPARTIDOR, con cuantos viajes tienen. */
    @GetMapping("/personas")
    public ResponseEntity<ApiResponse<List<PersonaViajesResponse>>> personas(@RequestParam String tipoUsuario) {
        return ResponseEntity.ok(ApiResponse.exito(viajeService.personasConViajes(tipoUsuario)));
    }
}
