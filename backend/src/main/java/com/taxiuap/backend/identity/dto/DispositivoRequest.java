package com.taxiuap.backend.identity.dto;

import com.taxiuap.backend.identity.enums.Plataforma;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Token de FCM del telefono (y su plataforma, ANDROID por defecto). */
public record DispositivoRequest(
        @NotBlank @Size(max = 255) String token,
        Plataforma plataforma) {
}
