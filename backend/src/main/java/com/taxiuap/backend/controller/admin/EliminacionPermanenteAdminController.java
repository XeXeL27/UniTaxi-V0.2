package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.dto.PersonaEliminableResponse;
import com.taxiuap.backend.identity.dto.ResumenEliminacionResponse;
import com.taxiuap.backend.identity.service.EliminacionPermanenteService;
import com.taxiuap.backend.shared.response.ApiResponse;

import lombok.RequiredArgsConstructor;

/** Personas > Eliminacion permanente: borrado fisico de una persona y todo lo suyo (ver el servicio). */
@RestController
@RequestMapping("/api/admin/eliminacion-permanente")
@RequiredArgsConstructor
public class EliminacionPermanenteAdminController {

    private final EliminacionPermanenteService eliminacionPermanenteService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<PersonaEliminableResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(eliminacionPermanenteService.listar()));
    }

    /** Que se borra y que se conserva, y si hoy se puede eliminar. */
    @GetMapping("/{idPersona}")
    public ResponseEntity<ApiResponse<ResumenEliminacionResponse>> resumen(@PathVariable Long idPersona) {
        return ResponseEntity.ok(ApiResponse.exito(eliminacionPermanenteService.resumen(idPersona, UsuarioActual.idUsuario())));
    }

    /** confirmacion: el correo de la persona (o su CI si no tiene correo), escrito por el administrador. */
    @DeleteMapping("/{idPersona}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long idPersona, @RequestParam String confirmacion) {
        eliminacionPermanenteService.eliminar(idPersona, confirmacion, UsuarioActual.idUsuario());
        return ResponseEntity.ok(ApiResponse.exito("Registro eliminado de forma permanente", null));
    }
}
