package com.taxiuap.backend.institution.dto;

import java.time.LocalDate;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Lo que responde el SIGSE de la UAP para un RU. matriculado = estado_matriculacion: solo con true se
 * registra como estudiante. foto: la imagen de url_imagen ya decodificada (null si no vino).
 * Son datos personales: nunca se devuelven enteros a la app (ver RegistroEstudianteUapResponse).
 */
public record DatosSigse(
        String ru,
        String ci,
        String nombres,
        String apellidoPaterno,
        String apellidoMaterno,
        LocalDate fechaNacimiento,
        String correo,
        String celular,
        String carrera,
        String facultad,
        String plan,
        Integer gestion,
        Integer periodo,
        String vigencia,
        boolean matriculado,
        byte[] foto) {

    /** Apellido paterno y materno, el que falte se omite. */
    public String apellidos() {
        return Stream.of(apellidoPaterno, apellidoMaterno)
                .filter(a -> a != null && !a.isBlank())
                .map(String::trim)
                .collect(Collectors.joining(" "));
    }

    public String nombreCompleto() {
        return (nombres == null ? "" : nombres.trim()) + " " + apellidos();
    }

    /** "1/2026": periodo y gestion de la matricula. */
    public String periodoAcademico() {
        if (vigencia != null && !vigencia.isBlank()) return vigencia.trim();
        return periodo != null && gestion != null ? periodo + "/" + gestion : null;
    }

    /** Celular util (SIGSE manda "0" cuando no lo tiene). */
    public String celularValido() {
        return celular != null && celular.trim().matches("[67]\\d{7}") ? celular.trim() : null;
    }
}
