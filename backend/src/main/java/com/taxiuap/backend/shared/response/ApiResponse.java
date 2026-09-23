package com.taxiuap.backend.shared.response;

import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.Map;

import com.fasterxml.jackson.annotation.JsonInclude;

import lombok.AllArgsConstructor;
import lombok.Getter;

import static lombok.AccessLevel.PRIVATE;

/**
 * Sobre estandar de toda respuesta HTTP del API. Se usa siempre, tanto en exito como en error,
 * para que el cliente (apps Flutter y panel admin) trate cualquier respuesta con la misma forma.
 */
@Getter
@AllArgsConstructor(access = PRIVATE)
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ApiResponse<T> {

    private static final ZoneId ZONA_LA_PAZ = ZoneId.of("America/La_Paz");

    private final boolean ok;
    private final String mensaje;
    private final T datos;
    private final Map<String, String> errores;
    private final OffsetDateTime fecha;

    public static <T> ApiResponse<T> exito(T datos) {
        return exito("Operacion exitosa", datos);
    }

    public static <T> ApiResponse<T> exito(String mensaje, T datos) {
        return new ApiResponse<>(true, mensaje, datos, null, OffsetDateTime.now(ZONA_LA_PAZ));
    }

    public static <T> ApiResponse<T> error(String mensaje) {
        return new ApiResponse<>(false, mensaje, null, null, OffsetDateTime.now(ZONA_LA_PAZ));
    }

    public static <T> ApiResponse<T> error(String mensaje, Map<String, String> errores) {
        return new ApiResponse<>(false, mensaje, null, errores, OffsetDateTime.now(ZONA_LA_PAZ));
    }
}
