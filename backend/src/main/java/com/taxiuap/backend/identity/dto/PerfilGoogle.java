package com.taxiuap.backend.identity.dto;

import java.util.Arrays;
import java.util.Locale;

/**
 * Datos de la persona que entrega Google (userinfo) ya repartidos como los guarda persona.
 *
 * Google manda el nombre completo y, casi siempre, tambien nombres (given_name) y apellidos
 * (family_name) por separado; si faltan se reparte el completo: con tres o mas palabras las dos
 * ultimas son apellidos (uso boliviano).
 */
public record PerfilGoogle(String correo, String nombres, String apellidos, String foto) {

    public static PerfilGoogle desde(String correo, String nombreCompleto, String dadoNombre, String apellido,
            String foto) {
        String nombres = limpiar(dadoNombre);
        String apellidos = limpiar(apellido);
        if (nombres == null || apellidos == null) {
            String[] partes = nombreCompleto == null ? new String[0] : nombreCompleto.trim().split("\\s+");
            if (partes.length == 0 || partes[0].isEmpty()) {
                nombres = nombres == null ? "Usuario" : nombres;
                apellidos = apellidos == null ? "Google" : apellidos;
            } else if (partes.length == 1) {
                nombres = nombres == null ? partes[0] : nombres;
                apellidos = apellidos == null ? "Sin especificar" : apellidos;
            } else {
                int corte = partes.length == 2 ? 1 : partes.length - 2;
                if (nombres == null) nombres = String.join(" ", Arrays.copyOfRange(partes, 0, corte));
                if (apellidos == null) apellidos = String.join(" ", Arrays.copyOfRange(partes, corte, partes.length));
            }
        }
        return new PerfilGoogle(correo.trim().toLowerCase(Locale.ROOT), nombres, apellidos, limpiar(foto));
    }

    private static String limpiar(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }
}
