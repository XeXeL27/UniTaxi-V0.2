package com.taxiuap.backend.shared.ia;

/**
 * Ningun lector con IA pudo leer la imagen: falta la llave, no hay conexion, se acabo la cuota o el
 * servicio rechazo el pedido. Quien llama decide que hacer (la app vuelve a leer con ML Kit en el
 * telefono y la cuenta queda en revision del administrador).
 */
public class IaNoDisponibleException extends RuntimeException {

    public IaNoDisponibleException(String mensaje) {
        super(mensaje);
    }
}
