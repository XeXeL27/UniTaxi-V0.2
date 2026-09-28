import '../core/cliente_api.dart';

/// Endpoints de la cuenta que valen para cualquier rol (/api/cuenta).
class CuentaApi {
  final ClienteApi cliente;

  CuentaApi(this.cliente);

  /// Cambia la contrasena; la de pasajero y la de conductor cambian juntas (son la misma).
  Future<void> cambiarContrasena({required String actual, required String nueva, required String confirmacion}) =>
      cliente.post('/api/cuenta/contrasena', {'actual': actual, 'nueva': nueva, 'confirmacion': confirmacion});
}
