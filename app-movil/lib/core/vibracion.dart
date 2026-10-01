import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'preferencias_aviso.dart';

/// Vibracion del telefono (solo el APK de Android; en el navegador no hace nada): dos pulsos
/// (MainActivity, como vibracion de notificacion). Avisa al pasajero cuando aceptan su viaje, cuando
/// llega el conductor y cuando termina el viaje. Se puede apagar en Mas > Sonido y vibracion.
class Vibracion {
  static const _canal = MethodChannel('unitaxi/vibracion');

  static Future<void> corta() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || !PreferenciasAviso.vibracion.value) return;
    try {
      await _canal.invokeMethod<void>('vibrar');
    } catch (_) {
      // Sin vibrador no pasa nada.
    }
  }
}
