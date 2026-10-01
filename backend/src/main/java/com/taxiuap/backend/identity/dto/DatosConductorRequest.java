package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;
import java.util.Map;

import com.taxiuap.backend.vehicle.enums.TipoDocumento;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Datos de conductor al habilitar su cuenta: licencia y vehiculo. En esta primera etapa el
 * vehiculo siempre es una motocicleta (licencia categoria M en el registro desde la app). vencimientos es opcional (fecha de vencimiento por tipo de
 * documento subido).
 */
public record DatosConductorRequest(
        @NotBlank @Size(max = 50) String numeroLicencia,
        @Pattern(regexp = ReglasRegistro.PATRON_CATEGORIA, message = ReglasRegistro.MENSAJE_CATEGORIA) String categoriaLicencia,
        @NotBlank @Size(max = 15) String placa,
        @NotBlank @Size(max = 100) @Pattern(regexp = ReglasRegistro.PATRON_MARCA, message = ReglasRegistro.MENSAJE_MARCA) String marca,
        @Size(max = 100) @Pattern(regexp = ReglasRegistro.PATRON_MODELO, message = ReglasRegistro.MENSAJE_MODELO) String modelo,
        @Size(max = 50) @Pattern(regexp = ReglasRegistro.PATRON_COLOR, message = ReglasRegistro.MENSAJE_COLOR) String color,
        @Min(1950) @Max(2100) Integer anio,
        Map<TipoDocumento, LocalDate> vencimientos,
        /** Vencimiento leido de la foto de la licencia (registro desde la app). */
        LocalDate vencimientoLicencia,
        /**
         * La app leyo la licencia con OCR y la verifico contra el carnet (mismo numero y mismo nombre).
         * Con los datos correctos el conductor queda APROBADO al registrarse.
         */
        Boolean licenciaVerificada) {
}
