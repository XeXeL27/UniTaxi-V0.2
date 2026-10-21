package com.taxiuap.backend.communication.dto;

import jakarta.validation.constraints.Size;

/**
 * Lo que el administrador escribe al atender un caso de Problemas de ingreso: el motivo para seguir
 * suspendida, el texto del correo o una nota al habilitar (opcional). cerrar solo vale para el correo:
 * false lo deja pendiente esperando la respuesta de la persona.
 */
public record RespuestaAyudaIngresoRequest(
        @Size(max = 1000, message = "El texto puede tener hasta 1000 caracteres") String texto,
        Boolean cerrar) {
}
