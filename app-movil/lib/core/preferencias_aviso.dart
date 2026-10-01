import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuracion de Mas > Sonido y vibracion: se guarda en el telefono y vale para toda la app
/// (avisos del viaje del pasajero y solicitudes nuevas del conductor). Las dos vienen encendidas.
class PreferenciasAviso {
  static const _claveSonido = 'taxiuap_app_sonido';
  static const _claveVibracion = 'taxiuap_app_vibracion';

  static final ValueNotifier<bool> sonido = ValueNotifier(true);
  static final ValueNotifier<bool> vibracion = ValueNotifier(true);

  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      sonido.value = prefs.getBool(_claveSonido) ?? true;
      vibracion.value = prefs.getBool(_claveVibracion) ?? true;
    } catch (_) {
      // Sin almacenamiento quedan encendidas.
    }
  }

  static Future<void> cambiarSonido(bool activo) => _guardar(_claveSonido, sonido, activo);

  static Future<void> cambiarVibracion(bool activo) => _guardar(_claveVibracion, vibracion, activo);

  static Future<void> _guardar(String clave, ValueNotifier<bool> valor, bool activo) async {
    valor.value = activo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(clave, activo);
    } catch (_) {
      // Queda en memoria mientras la app este abierta.
    }
  }
}
