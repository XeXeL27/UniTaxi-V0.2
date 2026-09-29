import '../core/cliente_api.dart';

/// Endpoints de la cuenta que valen para cualquier rol (/api/cuenta).
class CuentaApi {
  final ClienteApi cliente;

  CuentaApi(this.cliente);

  /// Cambia la contrasena; la de pasajero y la de conductor cambian juntas (son la misma).
  Future<void> cambiarContrasena({required String actual, required String nueva, required String confirmacion}) =>
      cliente.post('/api/cuenta/contrasena', {'actual': actual, 'nueva': nueva, 'confirmacion': confirmacion});

  /// Cambia los datos de Mi perfil confirmando con la contrasena; devuelve el usuario actualizado
  /// (UsuarioResponse) para la sesion.
  Future<Map<String, dynamic>> actualizarDatos(Map<String, dynamic> datos) async =>
      await cliente.put('/api/cuenta/datos', datos) as Map<String, dynamic>;
}
