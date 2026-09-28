package com.taxiuap.backend.sistema.dto;

/** Carpeta raiz vigente de los archivos, con lo que contiene. */
public record CarpetaArchivosResponse(
        String ruta,
        long cantidadArchivos,
        long tamanoBytes) {
}
