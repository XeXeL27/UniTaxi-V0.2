package com.taxiuap.backend.controller.admin;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.rating.service.CalificacionService;
import com.taxiuap.backend.shared.response.ApiResponse;

import lombok.RequiredArgsConstructor;

/** Moderacion de calificaciones y comentarios desde el panel. */
@RestController
@RequestMapping("/api/admin/calificaciones")
@RequiredArgsConstructor
public class CalificacionAdminController {

    private final CalificacionService calificacionService;

    /** Elimina la calificacion completa (borrado logico); el promedio del conductor se recalcula. */
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> eliminar(@PathVariable Long id) {
        calificacionService.eliminar(id);
        return ResponseEntity.ok(ApiResponse.exito("Calificacion eliminada", null));
    }

    /** Quita solo el comentario; las estrellas siguen contando. */
    @DeleteMapping("/{id}/comentario")
    public ResponseEntity<ApiResponse<Void>> quitarComentario(@PathVariable Long id) {
        calificacionService.quitarComentario(id);
        return ResponseEntity.ok(ApiResponse.exito("Comentario eliminado", null));
    }
}
