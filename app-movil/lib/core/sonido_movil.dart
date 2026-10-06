import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _canal = MethodChannel('unitaxi/vibracion');

/// Android: MainActivity lo reproduce como sonido de notificacion (respeta el modo silencio).
Future<void> sonarAviso(String archivo) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _canal.invokeMethod<void>('sonar', {'sonido': archivo});
  } catch (_) {
    // Sin audio no pasa nada.
  }
}
