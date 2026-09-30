import '../core/cliente_api.dart';

/// Endpoints de la cuenta que valen para cualquier rol (/api/cuenta).
class CuentaApi {
  final ClienteApi cliente;

  CuentaApi(this.cliente);

  /// Cambia la contrasena; la de pasajero y la de conductor cambian juntas (son la misma).
  Future<void> cambiarContrasena({required String actual, required String nueva, required String confirmacion}) =>
      cliente.post('/api/cuenta/contrasena', {'actual': actual, 'nueva': nueva, 'confirmacion': confirmacion});

  /// Pide el cambio de correo / telefono (y licencia en blanco): el backend envia un codigo al
  /// correo actual y devuelve ese correo oculto a medias ("ju*****@gmail.com").
  Future<String> pedirCodigoDatos(Map<String, dynamic> datos) async =>
      await cliente.post('/api/cuenta/datos/codigo', datos) as String;

  /// Aplica el cambio pendiente con el codigo; devuelve el usuario actualizado (UsuarioResponse).
  Future<Map<String, dynamic>> confirmarDatos(String codigo) async =>
      await cliente.put('/api/cuenta/datos', {'codigo': codigo}) as Map<String, dynamic>;
}
