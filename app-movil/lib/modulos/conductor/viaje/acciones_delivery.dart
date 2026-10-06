/// Validaciones que la app puede hacer sin conocer secretos del pedido.
class ValidadorCodigoDelivery {
  static final _patron = RegExp(r'^\d{6}$');

  static bool esValido(String valor) => _patron.hasMatch(valor.trim());
}

/// Reglas visuales para reportar un receptor ausente. La autorización final es del backend.
class EntregaSinContacto {
  static bool puedeReportar({required int intentos, required Duration espera}) =>
      intentos >= 2 && espera >= const Duration(minutes: 10);
}

/// Lo que el repartidor tiene que cobrar con el pedido en mano: el costo real del producto (0 en
/// ENCOMIENDA) más el precio del servicio.
///
/// El repartidor no escribe el monto, solo confirma que lo recibió, y el backend exige que sea
/// exactamente este. La suma se redondea a dos decimales porque en la app puede no serlo: con 0,05 de
/// producto y 0,10 de servicio, 0,05 + 0,10 da 0,15000000000000002, que el servidor rechazaría con un
/// mensaje que muestra el mismo número que se envió.
double totalAPagarEntrega({required double costoProducto, required double precioServicio}) =>
    ((costoProducto + precioServicio) * 100).round() / 100;
