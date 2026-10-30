package com.taxiuap.backend.trip.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Producto que el cliente pide comprar: nombre, cuantos y, si hace falta, indicaciones (marca, tamano). */
public record ProductoSolicitadoRequest(
        @NotBlank(message = "Escribe el nombre del producto")
        @Size(max = 150, message = "El nombre del producto admite hasta 150 caracteres") String nombre,
        @NotNull(message = "Indica cuantos necesitas")
        @Min(value = 1, message = "La cantidad debe ser al menos 1")
        @Max(value = 99, message = "La cantidad admite hasta 99") Integer cantidad,
        @Size(max = 300, message = "Las indicaciones admiten hasta 300 caracteres") String indicaciones) {
}
