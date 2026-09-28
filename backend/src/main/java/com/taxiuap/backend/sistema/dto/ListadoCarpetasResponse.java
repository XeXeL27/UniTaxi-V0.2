package com.taxiuap.backend.sistema.dto;

import java.util.List;

/** Contenido de una carpeta del servidor para el explorador del panel (solo subcarpetas). */
public record ListadoCarpetasResponse(
        String ruta,
        String padre,
        boolean escribible,
        List<Carpeta> carpetas) {

    public record Carpeta(String nombre, String ruta) {
    }
}
