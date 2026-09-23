package com.taxiuap.backend.config.security;

import java.util.Arrays;
import java.util.Optional;

/**
 * Unica fuente de verdad de la tabla {@code rol}. AdminInitializer (dominio identity) siembra
 * los roles base de la BD a partir de este enum al arrancar la aplicacion.
 */
public enum RolSistema {

    PASAJERO("PASAJERO", "Pasajero", "Solicita viajes y paga por ellos."),
    CONDUCTOR("CONDUCTOR", "Conductor", "Ofrece viajes con su vehiculo."),
    ADMIN("ADMIN", "Administrador", "Administra el sistema: aprobaciones, tarifas y reportes.");

    private final String codigo;
    private final String nombre;
    private final String descripcion;

    RolSistema(String codigo, String nombre, String descripcion) {
        this.codigo = codigo;
        this.nombre = nombre;
        this.descripcion = descripcion;
    }

    public String getCodigo() {
        return codigo;
    }

    public String getNombre() {
        return nombre;
    }

    public String getDescripcion() {
        return descripcion;
    }

    /** Autoridad de Spring Security correspondiente a este rol (ej. ROLE_ADMIN). */
    public String autoridad() {
        return "ROLE_" + codigo;
    }

    public static Optional<RolSistema> desdeCodigo(String codigo) {
        return Arrays.stream(values()).filter(r -> r.codigo.equals(codigo)).findFirst();
    }
}
