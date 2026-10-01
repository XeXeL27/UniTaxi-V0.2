package com.taxiuap.backend.identity.enums;

/** Que puede actualizar el conductor con un permiso de edicion. */
public enum TipoPermisoEdicion {
    /** Sus datos personales y de licencia. */
    DATOS,
    /** Reemplazar el PDF de un documento puntual. */
    DOCUMENTO,
    /** Volver a tomar las fotos del carnet (y con ellas el CI, complemento y fecha de nacimiento). */
    CARNET,
    /** Volver a tomar las fotos de la licencia (y con ellas el numero, la categoria y el vencimiento). */
    LICENCIA
}
