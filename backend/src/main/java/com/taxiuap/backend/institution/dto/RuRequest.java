package com.taxiuap.backend.institution.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/** Registro universitario (RU) de la UAP: solo numeros. */
public record RuRequest(
        @NotBlank(message = "Escribe tu RU")
        @Pattern(regexp = "\\d{1,10}", message = "El RU solo lleva números") String ru) {
}
