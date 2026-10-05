package com.taxiuap.backend.institution.dto;

import java.time.LocalDate;

/** Lo que dice el SIGSE de un RU, para que el administrador lo compare con el carnet (sin la foto). */
public record DatosSigseAdminResponse(
        String ru,
        String nombres,
        String apellidos,
        String ci,
        LocalDate fechaNacimiento,
        String correo,
        String carrera,
        String periodo,
        boolean matriculado) {

    public static DatosSigseAdminResponse de(DatosSigse d) {
        return new DatosSigseAdminResponse(d.ru(), d.nombres(), d.apellidos(), d.ci(), d.fechaNacimiento(),
                d.correo(), d.carrera(), d.periodoAcademico(), d.matriculado());
    }
}
