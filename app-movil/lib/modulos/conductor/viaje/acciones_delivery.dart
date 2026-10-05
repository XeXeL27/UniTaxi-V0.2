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
