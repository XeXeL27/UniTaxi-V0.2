package com.taxiuap.backend.identity.dto;

/**
 * Resultado de consultar un RU para registrarse como estudiante UAP. Solo lleva lo necesario para que
 * la persona se reconozca (nombre, carrera y el correo a medias): el CI, la fecha de nacimiento y el
 * correo completo nunca salen del servidor. codigo: para terminar el registro con las fotos del carnet
 * (null si ya tenia cuenta: en ese caso mensaje dice que hacer).
 */
public record RegistroEstudianteUapResponse(
        String codigo,
        String nombreCompleto,
        String carrera,
        String correo,
        boolean tieneCuenta,
        String mensaje) {
}
