package com.taxiuap.backend.communication.dto;

import java.util.List;

import com.taxiuap.backend.communication.enums.ProblemaIngreso;
import com.taxiuap.backend.identity.dto.ReglasRegistro;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Mensaje al administrador desde el login. identificador: usuario, correo, celular o carnet. password
 * (opcional): la que escribio en el login; si coincide con una cuenta suspendida el caso queda como
 * "Cuenta suspendida". descripcion es obligatoria con OTRO.
 */
public record AyudaIngresoLoginRequest(
        @NotBlank @Size(max = 120) String identificador,
        @Size(max = 200) String password,
        @NotEmpty(message = "Elige al menos un problema") List<ProblemaIngreso> problemas,
        @Size(max = 1000, message = "El motivo puede tener hasta 1000 caracteres") String descripcion,
        @NotBlank @Pattern(regexp = ReglasRegistro.PATRON_CELULAR, message = ReglasRegistro.MENSAJE_CELULAR)
        String celular) {
}
