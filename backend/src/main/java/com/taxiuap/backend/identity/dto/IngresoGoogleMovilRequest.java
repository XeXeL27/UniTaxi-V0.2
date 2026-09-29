package com.taxiuap.backend.identity.dto;

import com.taxiuap.backend.identity.enums.ModoIngresoGoogle;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Ingreso con Google desde el APK: el id_token que entrego Google Sign-In en el telefono y para que
 * se usa (INGRESO desde el login, PASAJERO o CONDUCTOR desde el registro).
 */
public record IngresoGoogleMovilRequest(@NotBlank String idToken, @NotNull ModoIngresoGoogle modo) {
}
