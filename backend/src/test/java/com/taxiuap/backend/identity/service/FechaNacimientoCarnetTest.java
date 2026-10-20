package com.taxiuap.backend.identity.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.time.LocalDate;

import org.junit.jupiter.api.Test;

import com.taxiuap.backend.identity.dto.LecturaDocumentoResponse;

/**
 * La fecha de nacimiento se toma del anverso (impresa con su etiqueta, dd/mm/aaaa): en la MRZ del reverso (AAMMDD)
 * la IA a veces invierte el mes y el dia. Datos inventados.
 */
class FechaNacimientoCarnetTest {

    private static LecturaDocumentoResponse con(LocalDate fecha) {
        return new LecturaDocumentoResponse(true, true, null, "NUEVO", "1234567", null, "JUAN", "PEREZ", "JUAN PEREZ",
                true, false, fecha, null, null);
    }

    @Test
    void siLasDosFotosDicenOtraFechaMandaElAnverso() {
        LocalDate anverso = LocalDate.of(1999, 8, 4);
        LocalDate reversoInvertido = LocalDate.of(1999, 4, 8);

        assertEquals(anverso, LecturaDocumentoService.fechaNacimiento(con(anverso), con(reversoInvertido)));
    }

    @Test
    void elCarnetAntiguoLaTraeSoloEnElReverso() {
        LocalDate reverso = LocalDate.of(1985, 12, 1);

        assertEquals(reverso, LecturaDocumentoService.fechaNacimiento(con(null), con(reverso)));
        assertEquals(reverso, LecturaDocumentoService.fechaNacimiento(null, con(reverso)));
        assertNull(LecturaDocumentoService.fechaNacimiento(null, null));
    }
}
