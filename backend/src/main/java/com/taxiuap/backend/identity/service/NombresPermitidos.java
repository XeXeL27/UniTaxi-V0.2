package com.taxiuap.backend.identity.service;

import java.text.Normalizer;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * Revisa que el nombre de una persona parezca un nombre real: sin groserias, albures ni palabras
 * de prueba. No rechaza el registro: si algo no cuadra, el carnet queda OBSERVADO y un
 * administrador lo revisa con las fotos (un apellido real puede parecerse a una palabra de la lista).
 */
public final class NombresPermitidos {

    /** Palabras que no pueden ser un nombre (se comparan sin tildes, en mayusculas y con 0->O, 1->I...). */
    private static final Set<String> PALABRAS = Set.of(
            "VERGA", "VERGAS", "VERGUDO", "VERGUDA", "VERGON", "VERGONA", "PENDEJO", "PENDEJA", "CABRON", "CABRONA",
            "PUTA", "PUTO", "PUTAS", "PUTITA", "MIERDA", "MIERDAS", "CULO", "CULON", "CULONA", "CULERO", "CULERA",
            "COJUDO", "COJUDA", "HUEVON", "HUEVONA", "HUEVUDO", "WEON", "WEVON", "MARICON", "MARICA", "MARACO",
            "CARAJO", "CHUCHA", "PICHULA", "PICHA", "PINGA", "PIJA", "PIJUDO", "PENE", "VAGINA", "TETA", "TETAS",
            "TETONA", "CHUPAPIJA", "CHUPAPINGA", "MAMAHUEVO", "MAMAHUEVOS", "CACHUDO", "CACHUDA", "JODER", "JODIDO",
            "ZORRA", "PERRA", "IMBECIL", "IDIOTA", "ESTUPIDO", "ESTUPIDA", "TARADO", "TARADA", "MONGOLICO",
            "OJETE", "CACA", "POTO", "CHOTA", "PAJERO", "PAJERA", "PAJA", "COGER", "COGIDO", "FOLLAR", "SEXO",
            "PORNO", "NALGA", "NALGAS", "PUÑETA", "PUNETA", "PUNETERO", "BOLUDO", "BOLUDA",
            "CHORO", "MALDITO", "MALDITA", "DIABLO", "SATANAS", "HITLER",
            // Palabras de prueba o de relleno.
            "PRUEBA", "TEST", "ASDF", "QWERTY", "XXX", "NOMBRE", "NOMBRES", "APELLIDO", "APELLIDOS", "NINGUNO",
            "ANONIMO", "USUARIO", "FULANO", "FULANA", "MENGANO", "PERENGANO");

    /**
     * Raices que no pueden ir dentro de una palabra ("ELVERGUDO", "SUPERPENDEJO"). VERGA no, porque
     * esta dentro de VERGARA.
     */
    private static final List<String> RAICES = List.of(
            "VERGUD", "PENDEJ", "MIERD", "MARICON", "CABRON", "HUEVON", "COJUD", "MAMAHUEV", "CHUPAPIJ",
            "CHUPAPING", "PICHUL", "PUNETER");

    private NombresPermitidos() {
    }

    /**
     * Motivo por el que el nombre no parece real, o null si esta bien. Revisa nombres y apellidos
     * juntos, palabra por palabra.
     */
    public static String problema(String nombres, String apellidos) {
        String completo = ((nombres == null ? "" : nombres) + " " + (apellidos == null ? "" : apellidos)).trim();
        if (completo.isEmpty()) {
            return "El nombre está vacío";
        }
        for (String original : completo.split("[\\s'-]+")) {
            if (original.isEmpty()) continue;
            String palabra = normalizar(original);
            if (PALABRAS.contains(palabra) || PALABRAS.contains(sinRepetidas(palabra))) {
                return "El nombre tiene una palabra no permitida (" + original.toUpperCase(Locale.ROOT) + ")";
            }
            for (String raiz : RAICES) {
                if (sinRepetidas(palabra).contains(raiz)) {
                    return "El nombre tiene una palabra no permitida (" + original.toUpperCase(Locale.ROOT) + ")";
                }
            }
            if (palabra.matches(".*\\d.*")) {
                return "El nombre tiene números (" + original + ")";
            }
            if (palabra.matches(".*(.)\\1\\1.*")) {
                return "El nombre tiene una letra repetida muchas veces (" + original + ")";
            }
            if (palabra.length() >= 3 && !palabra.matches(".*[AEIOUY].*")) {
                return "El nombre tiene una palabra sin vocales (" + original + ")";
            }
            if (palabra.length() == 1 && !palabra.equals("Y")) {
                return "El nombre tiene una letra suelta (" + original + ")";
            }
        }
        return null;
    }

    /**
     * Mayusculas sin tildes (la Ñ se conserva) y con los numeros que suelen reemplazar letras
     * (V3RGA, PUT4) cambiados por esas letras. Si despues quedan numeros, el nombre los tiene.
     */
    static String normalizar(String palabra) {
        String sinTildes = Normalizer.normalize(palabra.toUpperCase(Locale.ROOT).replace("Ñ", "\u0001"),
                Normalizer.Form.NFD).replaceAll("\\p{M}", "").replace("\u0001", "Ñ");
        String cambiada = sinTildes.replace('0', 'O').replace('1', 'I').replace('3', 'E').replace('4', 'A')
                .replace('5', 'S').replace('7', 'T').replace('@', 'A').replace('$', 'S');
        // Solo se toma el cambio si la palabra tenia letras: "12345" sigue siendo numeros.
        return sinTildes.matches(".*[A-ZÑ].*") ? cambiada : sinTildes;
    }

    /** "PUUUTA" -> "PUTA": las letras repetidas seguidas cuentan una vez. */
    private static String sinRepetidas(String palabra) {
        return palabra.replaceAll("(.)\\1+", "$1");
    }
}
