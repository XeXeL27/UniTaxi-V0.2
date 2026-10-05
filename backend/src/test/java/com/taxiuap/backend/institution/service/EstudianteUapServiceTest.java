package com.taxiuap.backend.institution.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.taxiuap.backend.institution.dto.DatosSigse;

/** Datos inventados: ninguna persona real. */
class EstudianteUapServiceTest {

    private static final DatosSigse SIGSE = new DatosSigse("10001", "7654321", "JUAN JOSÉ", "PEÑA", "QUISPE",
            LocalDate.of(2001, 3, 15), "juan.prueba@correo.test", "0", "Ingeniería de Sistemas", "Area", "2018",
            2026, 2, "2/2026", true, null);

    @Test
    void coincideSinImportarTildesNiEnes() {
        assertTrue(EstudianteUapService.diferencias(SIGSE, "7654321", LocalDate.of(2001, 3, 15), "JUAN JOSE",
                "PENA QUISPE").isEmpty());
    }

    @Test
    void avisaCadaDatoDistinto() {
        List<String> distintos = EstudianteUapService.diferencias(SIGSE, "7654320", LocalDate.of(2001, 3, 16),
                "JUAN", "PENA QUISPE");
        assertEquals(List.of("tu nombre", "tu número de carnet", "tu fecha de nacimiento"), distintos);
        assertEquals("tu nombre, tu número de carnet y tu fecha de nacimiento", EstudianteUapService.enFrase(distintos));
    }

    @Test
    void elComplementoNoCuentaParaElCi() {
        assertFalse(EstudianteUapService.diferencias(SIGSE, "7654321", LocalDate.of(2001, 3, 15), "JUAN JOSE",
                "PENA QUISPE").contains("tu número de carnet"));
    }

    @Test
    void leeLaRespuestaDelSigse() {
        DatosSigse d = ClienteSigse.convertir(Map.of(
                "ru", 10001, "ci", "7654321", "nombres", "JUAN JOSÉ", "apellido_paterno", "PEÑA",
                "apellido_materno", "QUISPE", "fecha_nacimiento", "2001-03-15", "correo", "juan.prueba@correo.test",
                "celular", "0", "estado_matriculacion", true, "vigencia", "2/2026"));
        assertEquals("10001", d.ru());
        assertEquals("PEÑA QUISPE", d.apellidos());
        assertEquals(LocalDate.of(2001, 3, 15), d.fechaNacimiento());
        assertTrue(d.matriculado());
        assertNull(d.celularValido());
        assertNull(d.foto());
        assertEquals("2/2026", d.periodoAcademico());
    }

    @Test
    void sinMatriculaEnTrueNoEstaMatriculado() {
        assertFalse(ClienteSigse.convertir(Map.of("ru", "1", "estado_matriculacion", false)).matriculado());
        assertFalse(ClienteSigse.convertir(Map.of("ru", "1")).matriculado());
    }
}
