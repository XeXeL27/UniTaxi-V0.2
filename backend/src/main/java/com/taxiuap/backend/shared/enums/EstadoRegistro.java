package com.taxiuap.backend.shared.enums;

/**
 * Estado de borrado logico usado por todos los campos estado_<entidad> del modelo de datos.
 * Los listados solo muestran registros en A; eliminar un registro lo pasa a X.
 */
public enum EstadoRegistro {
    /** Activo. */
    A,
    /** Eliminado (borrado logico). */
    X
}
