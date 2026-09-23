package com.taxiuap.backend.institution.dto;

import com.taxiuap.backend.institution.enums.ResultadoVerificacion;

import jakarta.validation.constraints.NotNull;

/** Datos de entrada para que un administrador resuelva una verificacion de matricula estudiantil. */
public record ResolverVerificacionRequest(

        @NotNull(message = "El resultado es obligatorio")
        ResultadoVerificacion resultado,

        String motivoRechazo
) {
}
