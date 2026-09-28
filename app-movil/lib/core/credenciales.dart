import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Usuario y contrasena recordados en el telefono ("Recordar usuario y contraseña" del login).
/// Se guardan cifrados (Keystore de Android) y siguen ahi aunque se cierre la sesion.
class Credenciales {
  static const _claveUsuario = 'taxiuap_recordar_usuario';
  static const _claveContrasena = 'taxiuap_recordar_contrasena';
  static const _almacen = FlutterSecureStorage();

  final String usuario;
  final String contrasena;

  const Credenciales(this.usuario, this.contrasena);

  static Future<Credenciales?> leer() async {
    try {
      final usuario = await _almacen.read(key: _claveUsuario);
      final contrasena = await _almacen.read(key: _claveContrasena);
      if (usuario == null || contrasena == null) return null;
      return Credenciales(usuario, contrasena);
    } catch (_) {
      return null;
    }
  }

  static Future<void> guardar(String usuario, String contrasena) async {
    try {
      await _almacen.write(key: _claveUsuario, value: usuario);
      await _almacen.write(key: _claveContrasena, value: contrasena);
    } catch (_) {
      // Si el almacenamiento seguro no esta disponible simplemente no se recuerda.
    }
  }

  static Future<void> olvidar() async {
    try {
      await _almacen.delete(key: _claveUsuario);
      await _almacen.delete(key: _claveContrasena);
    } catch (_) {
      // Nada que borrar.
    }
  }
}
