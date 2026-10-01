import '../core/cliente_api.dart';

/// Endpoints de la cuenta que valen para cualquier rol (/api/cuenta).
class CuentaApi {
  final ClienteApi cliente;

  CuentaApi(this.cliente);

  /// Cambia la contrasena; la de pasajero y la de conductor cambian juntas (son la misma).
  Future<void> cambiarContrasena({required String actual, required String nueva, required String confirmacion}) =>
      cliente.post('/api/cuenta/contrasena', {'actual': actual, 'nueva': nueva, 'confirmacion': confirmacion});

  /// Cambia el correo / telefono (y la licencia en blanco del conductor) confirmando con la
  /// contrasena; devuelve el usuario actualizado (UsuarioResponse).
  Future<Map<String, dynamic>> actualizarDatos(Map<String, dynamic> datos) async =>
      await cliente.put('/api/cuenta/datos', datos) as Map<String, dynamic>;

  /// La persona ya vio el aviso de que sus credenciales llegaron a su correo.
  Future<void> avisoCredencialesVisto() => cliente.post('/api/cuenta/aviso-credenciales', {});
}
