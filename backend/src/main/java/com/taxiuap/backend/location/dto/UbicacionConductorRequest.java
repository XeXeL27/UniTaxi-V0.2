package com.taxiuap.backend.location.dto;

import java.math.BigDecimal;

import com.taxiuap.backend.location.enums.Disponibilidad;
import com.taxiuap.backend.shared.exception.NegocioException;

/**
 * Posicion que reporta un conductor por WebSocket.
 *
 * Los rangos se comprueban aqui y no con anotaciones de Jakarta Validation porque el canal de
 * entrada de STOMP no ejecuta el validador sobre el cuerpo del frame. Asi ningun objeto de este tipo
 * puede existir con coordenadas invalidas, y el mensaje se rechaza al deserializarlo.
 *
 * El rumbo, la velocidad y la disponibilidad son opcionales: un conductor puede mandar solo el par
 * de coordenadas.
 */
public record UbicacionConductorRequest(
        BigDecimal latitud,
        BigDecimal longitud,
        BigDecimal rumbo,
        BigDecimal velocidad,
        Disponibilidad disponibilidad) {

    private static final BigDecimal LATITUD_MINIMA = new BigDecimal("-90");
    private static final BigDecimal LATITUD_MAXIMA = new BigDecimal("90");
    private static final BigDecimal LONGITUD_MINIMA = new BigDecimal("-180");
    private static final BigDecimal LONGITUD_MAXIMA = new BigDecimal("180");
    private static final BigDecimal CERO = BigDecimal.ZERO;
    private static final BigDecimal GRADOS_MAXIMOS = new BigDecimal("360");

    public UbicacionConductorRequest {
        exigir(latitud != null, "La posicion debe incluir la latitud");
        exigir(longitud != null, "La posicion debe incluir la longitud");
        exigir(enRango(latitud, LATITUD_MINIMA, LATITUD_MAXIMA), "La latitud debe estar entre -90 y 90");
        exigir(enRango(longitud, LONGITUD_MINIMA, LONGITUD_MAXIMA), "La longitud debe estar entre -180 y 180");
        exigir(rumbo == null || enRango(rumbo, CERO, GRADOS_MAXIMOS), "El rumbo debe estar entre 0 y 360 grados");
        exigir(velocidad == null || velocidad.compareTo(CERO) >= 0, "La velocidad no puede ser negativa");
    }

    private static boolean enRango(BigDecimal valor, BigDecimal minimo, BigDecimal maximo) {
        return valor.compareTo(minimo) >= 0 && valor.compareTo(maximo) <= 0;
    }

    private static void exigir(boolean condicion, String mensaje) {
        if (!condicion) {
            throw new NegocioException(mensaje);
        }
    }
}
