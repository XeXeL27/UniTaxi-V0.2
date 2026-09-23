package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;
import java.util.Map;

import com.taxiuap.backend.vehicle.enums.TipoDocumento;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Datos de conductor al habilitar su cuenta: licencia y vehiculo. En esta primera etapa el
 * vehiculo siempre es una motocicleta. vencimientos es opcional (fecha de vencimiento por tipo de
 * documento subido).
 */
public record DatosConductorRequest(
        @NotBlank @Size(max = 50) String numeroLicencia,
        @Size(max = 10) String categoriaLicencia,
        @NotBlank @Size(max = 15) String placa,
        @NotBlank @Size(max = 100) String marca,
        @Size(max = 100) String modelo,
        @Size(max = 50) String color,
        @Min(1950) @Max(2100) Integer anio,
        Map<TipoDocumento, LocalDate> vencimientos) {
}
