import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'preferencias_aviso.dart';

/// Vibracion del telefono (solo el APK de Android; en el navegador no hace nada): dos pulsos
/// (MainActivity, como vibracion de notificacion). Acompana a cada aviso con sonido. Se puede apagar
/// en Perfil > Sonido y vibracion.
class Vibracion {
  static const _canal = MethodChannel('unitaxi/vibracion');

  /// Lo que duran los dos pulsos (350 + 150 + 350 ms): dos avisos juntos vibran una vez, no se pisan.
  static const _duracion = Duration(milliseconds: 850);
  static DateTime _vibrandoHasta = DateTime.fromMillisecondsSinceEpoch(0);

  @visibleForTesting
  static DateTime Function() reloj = DateTime.now;

  static Future<void> corta() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || !PreferenciasAviso.vibracion.value) return;
    final ahora = reloj();
    if (ahora.isBefore(_vibrandoHasta)) return;
    _vibrandoHasta = ahora.add(_duracion);
    try {
      await _canal.invokeMethod<void>('vibrar');
    } catch (_) {
      // Sin vibrador no pasa nada.
    }
  }

  @visibleForTesting
  static void reiniciar() => _vibrandoHasta = DateTime.fromMillisecondsSinceEpoch(0);
}
