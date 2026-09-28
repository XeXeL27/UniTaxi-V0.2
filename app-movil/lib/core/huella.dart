import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'credenciales.dart';

/// Ingreso con huella (o Face ID / patron del telefono) en el APK de Android.
///
/// Al activarla se guardan el usuario y la contrasena cifrados en el telefono; en el login, si la
/// huella se reconoce, se inicia sesion con esas credenciales. En el navegador no existe.
class Huella {
  static const _claveUsuario = 'taxiuap_huella_usuario';
  static const _claveContrasena = 'taxiuap_huella_contrasena';
  static const _almacen = FlutterSecureStorage();
  static final _autenticacion = LocalAuthentication();

  /// Solo el APK de Android la ofrece.
  static bool get soportada => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// El telefono tiene huella o Face ID registrados.
  static Future<bool> disponible() async {
    if (!soportada) return false;
    try {
      if (!await _autenticacion.isDeviceSupported()) return false;
      return (await _autenticacion.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Hay credenciales guardadas para ingresar con huella.
  static Future<bool> activada() async => await _credenciales() != null;

  /// Pide la huella y, si se reconoce, guarda las credenciales. Devuelve false si se cancelo.
  static Future<bool> activar(String usuario, String contrasena) async {
    if (!await verificar('Confirma tu huella para activar el ingreso con huella')) return false;
    await _almacen.write(key: _claveUsuario, value: usuario);
    await _almacen.write(key: _claveContrasena, value: contrasena);
    return true;
  }

  static Future<void> desactivar() async {
    try {
      await _almacen.delete(key: _claveUsuario);
      await _almacen.delete(key: _claveContrasena);
    } catch (_) {
      // Nada que borrar.
    }
  }

  /// Pide la huella y devuelve las credenciales guardadas; null si no se reconocio o no hay.
  static Future<Credenciales?> ingresar() async {
    final guardadas = await _credenciales();
    if (guardadas == null) return null;
    if (!await verificar('Usa tu huella para ingresar a TaxiUAP')) return null;
    return guardadas;
  }

  /// Si la huella estaba activa, deja guardada la contrasena nueva (tras cambiarla).
  static Future<void> actualizarContrasena(String contrasena) async {
    if (await _credenciales() == null) return;
    await _almacen.write(key: _claveContrasena, value: contrasena);
  }

  static Future<bool> verificar(String motivo) async {
    try {
      return await _autenticacion.authenticate(localizedReason: motivo, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }

  static Future<Credenciales?> _credenciales() async {
    if (!soportada) return null;
    try {
      final usuario = await _almacen.read(key: _claveUsuario);
      final contrasena = await _almacen.read(key: _claveContrasena);
      if (usuario == null || contrasena == null) return null;
      return Credenciales(usuario, contrasena);
    } catch (_) {
      return null;
    }
  }
}
