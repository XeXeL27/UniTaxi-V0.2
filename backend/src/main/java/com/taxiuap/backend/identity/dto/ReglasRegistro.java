package com.taxiuap.backend.identity.dto;

/**
 * Formatos que se validan en el registro y en los cambios de datos: carnet, complemento, celular,
 * licencia y moto. Los nombres aceptan tildes y la letra Ñ.
 */
public final class ReglasRegistro {

    /** Solo los numeros del carnet, sin el complemento. */
    public static final String PATRON_CI = "^\\d{5,10}$";

    public static final String MENSAJE_CI = "El numero de carnet solo lleva numeros (de 5 a 10)";

    /**
     * Complemento del carnet (solo si lo tiene): dos caracteres con al menos un numero, por ejemplo
     * 1B. Asi no se confunde con la sigla del departamento (LP, PD...), que no es complemento.
     */
    public static final String PATRON_COMPLEMENTO = "^$|^(?=.*\\d)[0-9A-Za-z]{2}$";

    public static final String MENSAJE_COMPLEMENTO = "El complemento son dos caracteres con un numero, por ejemplo 1B";

    /** Celular boliviano: 8 digitos que empiezan con 6 o 7. */
    public static final String PATRON_CELULAR = "^[67]\\d{7}$";

    public static final String MENSAJE_CELULAR = "El celular debe tener 8 digitos y empezar con 6 o 7";

    /** Categorias de licencia en Bolivia: P particular, M motociclista, A, B y C profesional. */
    public static final String PATRON_CATEGORIA = "^$|^[PMABC]$";

    public static final String MENSAJE_CATEGORIA = "La categoria es una sola letra: P, M, A, B o C";

    /** Por ahora solo se aceptan conductores de moto. */
    public static final String CATEGORIA_MOTO = "M";

    /** Marca de la moto: solo letras en mayusculas (puede llevar espacios entre palabras). */
    public static final String PATRON_MARCA = "^[A-ZÑ]+( [A-ZÑ]+)*$";

    public static final String MENSAJE_MARCA = "La marca solo lleva letras en mayusculas";

    /** Modelo de la moto: letras y numeros (puede llevar espacio o guion entre ellos). */
    public static final String PATRON_MODELO = "^$|^[A-Za-z0-9Ññ]+([ -][A-Za-z0-9Ññ]+)*$";

    public static final String MENSAJE_MODELO = "El modelo solo lleva letras y numeros";

    /** Color: solo letras. */
    public static final String PATRON_COLOR = "^$|^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+( [A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*$";

    public static final String MENSAJE_COLOR = "El color solo lleva letras";

    /** Nombres y apellidos leidos del carnet: letras (con tildes y Ñ) y espacios. Vacio = no se envia. */
    public static final String PATRON_NOMBRE = "^$|^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+([ '-][A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*$";

    public static final String MENSAJE_NOMBRE = "El nombre solo lleva letras";

    /** El nombre leido del carnet manda; si no llego, queda el que ya tenia la persona. */
    public static String nombreOActual(String delCarnet, String actual) {
        return delCarnet == null || delCarnet.isBlank() ? actual : delCarnet.trim();
    }

    private ReglasRegistro() {
    }
}
